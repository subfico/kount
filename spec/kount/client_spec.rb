# frozen_string_literal: true

RSpec.describe Kount::Client do
  let(:api_key)    { "test_api_key" }
  let(:client_id)  { "test_client" }
  let(:auth_url)   { "https://login.kount.com/oauth2/ausdppkujzCPQuIrY357/v1/token" }
  let(:host) { "https://api.example.com" }

  let(:fake_adapter) do
    Class.new do
      def initialize
        @store = {}
      end

      def get_token(api_key:, client:)
        @store[[api_key, client]]
      end

      def store_token(api_key:, client:, token:, expires_in:)
        expiry = Time.now.to_i + expires_in
        @store[[api_key, client]] = { token: token, expiry: expiry }
      end
    end.new
  end

  let(:client_instance) do
    Kount::Client.new(
      api_key: api_key,
      client: client_id,
      auth_url: auth_url,
      host: host,
      token_storage_adapter: fake_adapter
    )
  end

  describe "#create_order" do
    let(:order) { { order_number: "123" } }
    let(:expected_url) { "#{host}/commerce/v2/orders?riskInquiry=true" }

    before do
      client_instance.bearer_token = "dummy_token"
    end

    it "calls post_order internally" do
      expect(client_instance).to receive(:post_order).with(order, true).and_call_original
      stub_request(:post, expected_url)
        .with(headers: { "Authorization" => "Bearer dummy_token", "Content-Type" => "application/json" })
        .to_return(status: 200, body: { order: { order_id: "123" } }.to_json)

      client_instance.create_order(order)
    end
  end

  describe "#update_order" do
    let(:order_id) { "123" }
    let(:order) { { status: "updated" } }
    let(:expected_url) { "#{host}/commerce/v2/orders/#{order_id}" }

    before do
      client_instance.bearer_token = "dummy_token"
    end

    it "calls patch_order internally" do
      expect(client_instance).to receive(:patch_order).with(order_id, order).and_call_original
      stub_request(:patch, expected_url)
        .with(headers: { "Authorization" => "Bearer dummy_token", "Content-Type" => "application/json" })
        .to_return(status: 200, body: { order: { result: "patched" } }.to_json)

      client_instance.update_order(order_id, order)
    end
  end
end
