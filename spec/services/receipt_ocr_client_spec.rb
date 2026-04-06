# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReceiptOcrClient do
  let(:valid_response_json) do
    { description: 'Starbucks', date: '2025-04-01', amount: '12.50', trx_type: 'debit' }.to_json
  end

  def fake_openai_response(content)
    { 'choices' => [{ 'message' => { 'content' => content } }] }
  end

  describe '#process' do
    context 'when no client is configured' do
      it 'returns nil' do
        result = described_class.new(client: nil).process(attachments: [])
        expect(result).to be_nil
      end
    end

    context 'when there are no image attachments' do
      it 'returns nil' do
        non_image = double('attachment', content_type: 'application/pdf')
        client = described_class.new(client: double('openai_client'))
        result = client.process(attachments: [non_image])
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

        result = client.process(attachments: [attachment])

        expect(result).to be_a(ReceiptOcrClient::OcrResult)
        expect(result.description).to eq('Starbucks')
        expect(result.date).to eq('2025-04-01')
        expect(result.amount).to eq('12.50')
        expect(result.trx_type).to eq('debit')
      end

      it 'handles JSON wrapped in markdown code fences' do
        content = "```json\n#{valid_response_json}\n```"
        openai_client = instance_double(OpenAI::Client,
                                        chat: fake_openai_response(content))
        result = described_class.new(client: openai_client).process(attachments: [attachment])

        expect(result.description).to eq('Starbucks')
        expect(result.amount).to eq('12.50')
      end

      it 'returns "credit" trx_type when response says credit' do
        content = { description: 'Refund', date: '2025-04-01', amount: '5.00', trx_type: 'credit' }.to_json
        openai_client = instance_double(OpenAI::Client,
                                        chat: fake_openai_response(content))
        result = described_class.new(client: openai_client).process(attachments: [attachment])

        expect(result.trx_type).to eq('credit')
      end

      it 'defaults trx_type to debit when response is unknown' do
        content = { description: 'Coffee', date: '2025-04-01', amount: '4.00', trx_type: 'unknown' }.to_json
        openai_client = instance_double(OpenAI::Client,
                                        chat: fake_openai_response(content))
        result = described_class.new(client: openai_client).process(attachments: [attachment])

        expect(result.trx_type).to eq('debit')
      end

      it 'returns nil when the API response is unparseable JSON' do
        openai_client = instance_double(OpenAI::Client,
                                        chat: fake_openai_response('not json at all'))
        result = described_class.new(client: openai_client).process(attachments: [attachment])

        expect(result).to be_nil
      end

      it 'returns nil when a Faraday network error occurs' do
        openai_client = instance_double(OpenAI::Client)
        allow(openai_client).to receive(:chat).and_raise(Faraday::ConnectionFailed.new('connection refused'))
        result = described_class.new(client: openai_client).process(attachments: [attachment])

        expect(result).to be_nil
      end

      it 'returns nil when a generic error occurs' do
        openai_client = instance_double(OpenAI::Client)
        allow(openai_client).to receive(:chat).and_raise(StandardError, 'something went wrong')
        result = described_class.new(client: openai_client).process(attachments: [attachment])

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
        content = { description: 'Target', date: '2025-04-01', amount: '$34.99', trx_type: 'debit' }.to_json
        openai_client = instance_double(OpenAI::Client, chat: fake_openai_response(content))
        result = described_class.new(client: openai_client).process(attachments: [attachment])

        expect(result.amount).to eq('34.99')
      end

      it 'returns nil amount when value is null in response' do
        content = { description: 'Unknown', date: '2025-04-01', amount: nil, trx_type: 'debit' }.to_json
        openai_client = instance_double(OpenAI::Client, chat: fake_openai_response(content))
        result = described_class.new(client: openai_client).process(attachments: [attachment])

        expect(result.amount).to be_nil
      end
    end
  end
end
