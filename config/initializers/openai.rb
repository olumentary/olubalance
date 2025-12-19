if ENV["OPENAI_API_KEY"].present?
  OpenAI.configure do |config|
    config.access_token = ENV["OPENAI_API_KEY"]
    config.request_timeout = 10
  end
end

