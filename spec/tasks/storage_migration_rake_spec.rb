# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'storage:migrate_blobs_to_linode rake task' do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:migrate_task) { Rake::Task['storage:migrate_blobs_to_linode'] }

  # Unverified doubles are used here to sidestep instance_double method
  # verification issues with abstract base classes like ActiveStorage::Service.
  let(:source_service) { double('source_service') }
  let(:dest_service)   { double('dest_service') }

  # Preserve and restore the original services registry so tests don't leak.
  let(:original_services) { ActiveStorage::Blob.services }

  before do
    # Directly patch the services registry so `ActiveStorage::Blob.services.fetch`
    # returns our doubles without needing real S3 credentials.
    # We use a registry double that returns dest_service for 'linode' and
    # source_service for everything else (including amazon, amazondev, etc.).
    original_services  # eager-evaluate to memoize before patching
    services_double = double('services_registry')
    # IMPORTANT: RSpec uses unshift for stubs (last added = first checked), so
    # generic stubs must be added BEFORE specific ones so that specific stubs
    # end up at the front of the list and are checked first.
    allow(services_double).to receive(:fetch).and_return(source_service)
    allow(services_double).to receive(:fetch).with('linode').and_return(dest_service)
    allow(services_double).to receive(:fetch).with(:linode).and_return(dest_service)
    allow(ActiveStorage::Blob).to receive(:services).and_return(services_double)

    # All blob instances return source_service when asked for their service.
    # This covers the `source_service = blob.service` call inside the task loop.
    allow_any_instance_of(ActiveStorage::Blob).to receive(:service).and_return(source_service)

    # Default happy-path behaviour: download yields one chunk, upload returns nil.
    allow(source_service).to receive(:download).and_yield('fake file bytes')
    allow(dest_service).to receive(:exist?).and_return(false)
    allow(dest_service).to receive(:upload)

    # ActiveStorage fires an after_create_commit callback that calls update_metadata
    # on the blob's service when an Attachment record is created.
    allow(source_service).to receive(:update_metadata)
    allow(dest_service).to receive(:update_metadata)
  end

  after do
    migrate_task.reenable
    %w[BATCH_SIZE BATCH_PAUSE DRY_RUN SOURCE_SERVICE].each { |k| ENV.delete(k) }
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  let(:account) { create(:account) }

  # Creates a blob+attachment pair that looks like a pre-migration amazon blob.
  # No actual file is written to storage — service interactions are mocked.
  def create_pending_blob(filename: 'receipt.txt', service_name: 'amazon', txn: nil)
    txn ||= create(:transaction, :non_pending, account: account)
    blob = ActiveStorage::Blob.create!(
      key:          SecureRandom.base58(24),
      filename:     filename,
      content_type: 'text/plain',
      byte_size:    128,
      checksum:     Digest::MD5.base64digest('fake file bytes'),
      service_name: service_name
    )
    ActiveStorage::Attachment.create!(name: 'attachments', record: txn, blob: blob)
    blob
  end

  # ── Core migration behaviour ─────────────────────────────────────────────────

  context 'when there are pending blobs' do
    let!(:blob_1) { create_pending_blob(filename: 'receipt-1.txt') }
    let!(:blob_2) { create_pending_blob(filename: 'receipt-2.txt') }
    let!(:blob_3) { create_pending_blob(filename: 'receipt-3.txt') }

    it 'updates service_name to linode for all pending blobs' do
      migrate_task.invoke

      [blob_1, blob_2, blob_3].each do |blob|
        expect(blob.reload.service_name).to eq('linode')
      end
    end

    it 'downloads each blob from the source service using its original key' do
      migrate_task.invoke

      [blob_1, blob_2, blob_3].each do |blob|
        expect(source_service).to have_received(:download).with(blob.key)
      end
    end

    it 'uploads each blob to the destination service using the same key and checksum' do
      migrate_task.invoke

      [blob_1, blob_2, blob_3].each do |blob|
        expect(dest_service).to have_received(:upload).with(blob.key, anything, checksum: blob.checksum)
      end
    end
  end

  # ── Batch limiting ───────────────────────────────────────────────────────────

  context 'when BATCH_SIZE is set' do
    let!(:blobs) { 5.times.map { |i| create_pending_blob(filename: "receipt-#{i}.txt") } }

    before { ENV['BATCH_SIZE'] = '2' }

    it 'migrates exactly BATCH_SIZE blobs' do
      migrate_task.invoke

      migrated = blobs.count { |b| b.reload.service_name == 'linode' }
      expect(migrated).to eq(2)
    end

    it 'leaves the remaining blobs on amazon' do
      migrate_task.invoke

      still_pending = blobs.count { |b| b.reload.service_name == 'amazon' }
      expect(still_pending).to eq(3)
    end
  end

  # ── Resumability ─────────────────────────────────────────────────────────────

  context 'when the task is re-run after a partial migration' do
    let!(:already_migrated) { create_pending_blob(filename: 'done.txt',    service_name: 'linode') }
    let!(:pending_blob)     { create_pending_blob(filename: 'pending.txt', service_name: 'amazon') }

    it 'does not re-process blobs whose service_name is already linode' do
      migrate_task.invoke

      # Only the pending blob should have been uploaded
      expect(dest_service).to have_received(:upload).once
      expect(source_service).to have_received(:download).once
    end

    it 'migrates only the remaining pending blob' do
      migrate_task.invoke

      expect(pending_blob.reload.service_name).to eq('linode')
    end

    it 'does not alter the service_name of the already-migrated blob' do
      expect { migrate_task.invoke }
        .not_to change { already_migrated.reload.service_name }
    end
  end

  # ── Already in Linode bucket (DB inconsistency) ───────────────────────────────

  context 'when a blob exists in the Linode bucket but DB still says amazon' do
    let!(:blob_in_bucket) { create_pending_blob(filename: 'already-there.txt') }
    let!(:normal_blob)    { create_pending_blob(filename: 'normal.txt') }

    before do
      # blob_in_bucket is physically present on Linode (upload succeeded in a
      # prior run) but service_name was never updated (crash before update_column).
      allow(dest_service).to receive(:exist?).with(blob_in_bucket.key).and_return(true)
      allow(dest_service).to receive(:exist?).with(normal_blob.key).and_return(false)
    end

    it 'flips the DB record without re-uploading for the blob already in the bucket' do
      migrate_task.invoke

      expect(blob_in_bucket.reload.service_name).to eq('linode')
      expect(dest_service).not_to have_received(:upload).with(blob_in_bucket.key, anything, anything)
    end

    it 'still uploads and migrates blobs not yet in the bucket' do
      migrate_task.invoke

      expect(normal_blob.reload.service_name).to eq('linode')
      expect(dest_service).to have_received(:upload).with(normal_blob.key, anything, anything)
    end
  end

  # ── Dry run ──────────────────────────────────────────────────────────────────

  context 'when DRY_RUN=1 is set' do
    let!(:blob_1) { create_pending_blob(filename: 'receipt-1.txt') }
    let!(:blob_2) { create_pending_blob(filename: 'receipt-2.txt') }

    before { ENV['DRY_RUN'] = '1' }

    it 'does not change the service_name of any blob' do
      migrate_task.invoke

      [blob_1, blob_2].each do |blob|
        expect(blob.reload.service_name).to eq('amazon')
      end
    end

    it 'never calls upload on the destination service' do
      migrate_task.invoke

      expect(dest_service).not_to have_received(:upload)
    end

    it 'never calls download on the source service' do
      migrate_task.invoke

      expect(source_service).not_to have_received(:download)
    end
  end

  # ── Error handling ───────────────────────────────────────────────────────────

  context 'when a single blob fails to download' do
    # Create good blobs first so they have lower IDs and are processed before
    # the failing blob (task uses order(:id)).
    let!(:good_blob_1)  { create_pending_blob(filename: 'good-1.txt') }
    let!(:good_blob_2)  { create_pending_blob(filename: 'good-2.txt') }
    let!(:failing_blob) { create_pending_blob(filename: 'broken.txt') }

    before do
      # Override the global download stub: fail only for the failing blob's key.
      allow(source_service).to receive(:download) do |key, &block|
        raise 'S3 connection timeout' if key == failing_blob.key
        block.call('fake file bytes') if block
      end
    end

    it 'continues migrating the other blobs' do
      migrate_task.invoke

      expect(good_blob_1.reload.service_name).to eq('linode')
      expect(good_blob_2.reload.service_name).to eq('linode')
    end

    it 'leaves the failed blob unchanged' do
      migrate_task.invoke

      expect(failing_blob.reload.service_name).to eq('amazon')
    end

    it 'does not raise an unhandled exception' do
      expect { migrate_task.invoke }.not_to raise_error
    end
  end

  # ── No-op when nothing pending ───────────────────────────────────────────────

  context 'when there are no pending blobs' do
    it 'completes without error' do
      expect { migrate_task.invoke }.not_to raise_error
    end

    it 'does not interact with any storage service' do
      migrate_task.invoke

      expect(source_service).not_to have_received(:download)
      expect(dest_service).not_to have_received(:upload)
    end
  end

  # ── Custom SOURCE_SERVICE ────────────────────────────────────────────────────

  context 'when SOURCE_SERVICE is set to a custom value' do
    let!(:amazondev_blob) { create_pending_blob(filename: 'dev-receipt.txt',  service_name: 'amazondev') }
    let!(:amazon_blob)    { create_pending_blob(filename: 'prod-receipt.txt', service_name: 'amazon') }

    before { ENV['SOURCE_SERVICE'] = 'amazondev' }

    it 'migrates only blobs from the specified source service' do
      migrate_task.invoke

      expect(amazondev_blob.reload.service_name).to eq('linode')
    end

    it 'leaves blobs from other services untouched' do
      migrate_task.invoke

      expect(amazon_blob.reload.service_name).to eq('amazon')
    end
  end
end
