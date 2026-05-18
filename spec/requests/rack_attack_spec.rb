# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rack::Attack", type: :request do
  before do
    # Rack::Attack is bypassed in test env by default. Flip the switch and
    # provide a real memory cache so throttle counters work for this spec only.
    Rack::Attack.enabled = true
    @prev_cache = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    allow_any_instance_of(LoginEvent).to receive(:notify) # silence email alerts
  end

  after do
    Rack::Attack.cache.store = @prev_cache
    Rack::Attack.enabled = false
  end

  let(:credentials) { { user: { email: "victim@example.com", password: "wrong" } } }

  it "throttles after the 5th bad login attempt from a given IP" do
    5.times { post user_session_path, params: credentials, headers: { "REMOTE_ADDR" => "203.0.113.5" } }
    post user_session_path, params: credentials, headers: { "REMOTE_ADDR" => "203.0.113.5" }
    expect(response).to have_http_status(:too_many_requests)
  end

  it "writes a LoginEvent throttle row when triggered" do
    5.times { post user_session_path, params: credentials, headers: { "REMOTE_ADDR" => "203.0.113.6" } }
    expect {
      post user_session_path, params: credentials, headers: { "REMOTE_ADDR" => "203.0.113.6" }
    }.to change(LoginEvent.where(event_type: "throttle"), :count).by_at_least(1)
  end

  it "does not throttle an unrelated IP+email combination" do
    5.times { post user_session_path, params: credentials, headers: { "REMOTE_ADDR" => "203.0.113.7" } }
    # Different IP AND different email — neither throttle bucket should be hot.
    post user_session_path,
         params:  { user: { email: "different@example.com", password: "wrong" } },
         headers: { "REMOTE_ADDR" => "203.0.113.8" }
    expect(response).not_to have_http_status(:too_many_requests)
  end

  it "throttles per email across different IPs" do
    5.times.with_index do |_, i|
      post user_session_path, params: credentials, headers: { "REMOTE_ADDR" => "203.0.113.10#{i}" }
    end
    post user_session_path, params: credentials, headers: { "REMOTE_ADDR" => "203.0.113.200" }
    expect(response).to have_http_status(:too_many_requests)
  end
end
