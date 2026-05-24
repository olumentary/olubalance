# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReceiptOcrClient do
  let(:reference_date) { Date.current }
  let(:recent_date)    { (reference_date - 5).strftime('%Y-%m-%d') }

  let(:valid_response_json) do
    {
      description:     'Starbucks',
      date:            recent_date,
      date_confidence: 'high',
      amount:          '12.50',
      trx_type:        'debit'
    }.to_json
  end

  def fake_openai_response(content)
    { 'choices' => [ { 'message' => { 'content' => content } } ] }
  end

  describe '#process' do
    context 'when no client is configured' do
      it 'returns nil' do
        result = described_class.new(client: nil).process(attachments: [], reference_date: reference_date)
        expect(result).to be_nil
      end
    end

    context 'when there are no image attachments' do
      it 'returns nil' do
        non_image = double('attachment', content_type: 'application/pdf')
        client = described_class.new(client: double('openai_client'))
        result = client.process(attachments: [ non_image ], reference_date: reference_date)
        expect(result).to be_nil
      end
    end

    context 'with a valid image attachment and successful API response' do
      let(:image_data) { File.read(Rails.root.join('app/assets/images/logo.png'), encoding: 'binary') }
      let(:attachment) do
        double('attachment',
               content_type: 'image/png',
               blob: double('blob', download: image_data))
      end

      it 'returns an OcrResult with extracted fields' do
        openai_client = instance_double(OpenAI::Client,
                                        chat: fake_openai_response(valid_response_json))
        client = described_class.new(client: openai_client)

        result = client.process(attachments: [ attachment ], reference_date: reference_date)

        expect(result).to be_a(ReceiptOcrClient::OcrResult)
        expect(result.description).to eq('Starbucks')
        expect(result.date).to eq(recent_date)
        expect(result.date_confidence).to eq('high')
        expect(result.amount).to eq('12.50')
        expect(result.trx_type).to eq('debit')
      end

      it 'handles JSON wrapped in markdown code fences' do
        content = "```json\n#{valid_response_json}\n```"
        openai_client = instance_double(OpenAI::Client,
                                        chat: fake_openai_response(content))
        result = described_class.new(client: openai_client).process(attachments: [ attachment ], reference_date: reference_date)

        expect(result.description).to eq('Starbucks')
        expect(result.amount).to eq('12.50')
      end

      it 'returns "credit" trx_type when response says credit' do
        content = {
          description: 'Refund', date: recent_date, date_confidence: 'high',
          amount: '5.00', trx_type: 'credit'
        }.to_json
        openai_client = instance_double(OpenAI::Client,
                                        chat: fake_openai_response(content))
        result = described_class.new(client: openai_client).process(attachments: [ attachment ], reference_date: reference_date)

        expect(result.trx_type).to eq('credit')
      end

      it 'defaults trx_type to debit when response is unknown' do
        content = {
          description: 'Coffee', date: recent_date, date_confidence: 'high',
          amount: '4.00', trx_type: 'unknown'
        }.to_json
        openai_client = instance_double(OpenAI::Client,
                                        chat: fake_openai_response(content))
        result = described_class.new(client: openai_client).process(attachments: [ attachment ], reference_date: reference_date)

        expect(result.trx_type).to eq('debit')
      end

      it 'returns nil when the API response is unparseable JSON' do
        openai_client = instance_double(OpenAI::Client,
                                        chat: fake_openai_response('not json at all'))
        result = described_class.new(client: openai_client).process(attachments: [ attachment ], reference_date: reference_date)

        expect(result).to be_nil
      end

      it 'returns nil when a Faraday network error occurs' do
        openai_client = instance_double(OpenAI::Client)
        allow(openai_client).to receive(:chat).and_raise(Faraday::ConnectionFailed.new('connection refused'))
        result = described_class.new(client: openai_client).process(attachments: [ attachment ], reference_date: reference_date)

        expect(result).to be_nil
      end

      it 'returns nil when a generic error occurs' do
        openai_client = instance_double(OpenAI::Client)
        allow(openai_client).to receive(:chat).and_raise(StandardError, 'something went wrong')
        result = described_class.new(client: openai_client).process(attachments: [ attachment ], reference_date: reference_date)

        expect(result).to be_nil
      end
    end

    context 'amount parsing' do
      let(:image_data) { File.read(Rails.root.join('app/assets/images/logo.png'), encoding: 'binary') }
      let(:attachment) do
        double('attachment',
               content_type: 'image/png',
               blob: double('blob', download: image_data))
      end

      it 'strips currency symbols from the amount' do
        content = {
          description: 'Target', date: recent_date, date_confidence: 'high',
          amount: '$34.99', trx_type: 'debit'
        }.to_json
        openai_client = instance_double(OpenAI::Client, chat: fake_openai_response(content))
        result = described_class.new(client: openai_client).process(attachments: [ attachment ], reference_date: reference_date)

        expect(result.amount).to eq('34.99')
      end

      it 'returns nil amount when value is null in response' do
        content = {
          description: 'Unknown', date: recent_date, date_confidence: 'high',
          amount: nil, trx_type: 'debit'
        }.to_json
        openai_client = instance_double(OpenAI::Client, chat: fake_openai_response(content))
        result = described_class.new(client: openai_client).process(attachments: [ attachment ], reference_date: reference_date)

        expect(result.amount).to be_nil
      end
    end

    context 'date validation' do
      let(:image_data) { File.read(Rails.root.join('app/assets/images/logo.png'), encoding: 'binary') }
      let(:attachment) do
        double('attachment',
               content_type: 'image/png',
               blob: double('blob', download: image_data))
      end

      def run_with_date(date:, confidence:, reference_date:)
        content = {
          description: 'Acme', date: date, date_confidence: confidence,
          amount: '9.99', trx_type: 'debit'
        }.to_json
        openai_client = instance_double(OpenAI::Client, chat: fake_openai_response(content))
        described_class.new(client: openai_client).process(
          attachments:    [ attachment ],
          reference_date: reference_date
        )
      end

      it 'accepts a high-confidence date inside the 60-day window' do
        result = run_with_date(
          date:           (Date.current - 10).strftime('%Y-%m-%d'),
          confidence:     'high',
          reference_date: Date.current
        )
        expect(result.date).to eq((Date.current - 10).strftime('%Y-%m-%d'))
      end

      it 'drops a high-confidence date older than 60 days before today' do
        result = run_with_date(
          date:           (Date.current - 200).strftime('%Y-%m-%d'),
          confidence:     'high',
          reference_date: Date.current
        )
        expect(result.date).to be_nil
        expect(result.date_confidence).to eq('high')
      end

      it 'drops a high-confidence future date' do
        result = run_with_date(
          date:           (Date.current + 5).strftime('%Y-%m-%d'),
          confidence:     'high',
          reference_date: Date.current
        )
        expect(result.date).to be_nil
      end

      it 'drops a low-confidence date even when it is inside the window' do
        result = run_with_date(
          date:           (Date.current - 3).strftime('%Y-%m-%d'),
          confidence:     'low',
          reference_date: Date.current
        )
        expect(result.date).to be_nil
        expect(result.date_confidence).to eq('low')
      end

      it 'drops the date when date_confidence is missing entirely' do
        content = {
          description: 'Acme', date: (Date.current - 3).strftime('%Y-%m-%d'),
          amount: '9.99', trx_type: 'debit'
        }.to_json
        openai_client = instance_double(OpenAI::Client, chat: fake_openai_response(content))
        result = described_class.new(client: openai_client).process(
          attachments: [ attachment ], reference_date: Date.current
        )
        expect(result.date).to be_nil
      end

      it 'relaxes the floor to reference_date when reference_date is older than 60 days' do
        old_ref = Date.current - 90
        # A date matching the reference_date itself (which is older than the 60-day
        # default floor) must be accepted — otherwise the original creation date
        # would always be wiped out when reviewing aged quick receipts.
        result = run_with_date(
          date:           old_ref.strftime('%Y-%m-%d'),
          confidence:     'high',
          reference_date: old_ref
        )
        expect(result.date).to eq(old_ref.strftime('%Y-%m-%d'))
      end

      it 'still rejects dates older than the relaxed floor' do
        old_ref = Date.current - 90
        result = run_with_date(
          date:           (old_ref - 1).strftime('%Y-%m-%d'),
          confidence:     'high',
          reference_date: old_ref
        )
        expect(result.date).to be_nil
      end
    end
  end
end
