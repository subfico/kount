# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"
require "base64"
require "json"
require "kount/client"

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

  describe "#initialize" do
    context "with a valid token_storage_adapter" do
      it "does not raise an error" do
        expect { client_instance }.not_to raise_error
      end
    end

    context "with an invalid token_storage_adapter" do
      it "raises an ArgumentError" do
        expect do
          Kount::Client.new(
            api_key: api_key,
            client: client_id,
            auth_url: auth_url,
            host: host,
            token_storage_adapter: Object.new
          )
        end.to raise_error(ArgumentError, /Token storage adapter must implement get_token and store_token/)
      end
    end
  end

  describe "#authenticate" do
    context "when no token is cached" do
      it "fetches a new token from the auth endpoint" do
        stub_request(:post, auth_url)
          .with(
            headers: {
              "Authorization" => "Basic #{api_key}",
              "Content-Type" => "application/x-www-form-urlencoded"
            }
          )
          .to_return(
            status: 200,
            body: { "access_token" => "new_token", "expires_in" => 1200 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = client_instance.authenticate
        expect(result).to eq("new_token")
      end
    end

    context "when a valid token is cached" do
      it "returns the cached token without making a network request" do
        fake_adapter.store_token(api_key: api_key, client: client_id, token: "cached_token", expires_in: 1000)
        # Ensure no HTTP request is made
        expect(WebMock).not_to have_requested(:post, auth_url)
        result = client_instance.authenticate
        expect(result).to eq("cached_token")
      end
    end

    context "when the cached token is expired" do
      it "fetches a new token" do
        fake_adapter.store_token(api_key: api_key, client: client_id, token: "expired_token", expires_in: -10)

        stub_request(:post, auth_url)
          .with(
            headers: {
              "Authorization" => "Basic #{api_key}",
              "Content-Type" => "application/x-www-form-urlencoded"
            },
            body: "grant_type=client_credentials&scope=k1_integration_api"
          )
          .to_return(
            status: 200,
            body: { "access_token" => "refreshed_token", "expires_in" => 1200 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = client_instance.authenticate
        expect(result).to eq("refreshed_token")
      end
    end

    context "when authentication fails" do
      it "raises an error" do
        stub_request(:post, auth_url)
          .with(
            headers: {
              "Authorization" => "Basic #{api_key}",
              "Content-Type" => "application/x-www-form-urlencoded"
            },
            body: "grant_type=client_credentials&scope=k1_integration_api"
          )
          .to_return(status: 401, body: "Unauthorized")

        expect { client_instance.authenticate }.to raise_error(RuntimeError, /Authentication failed/)
      end
    end
  end

  describe "#post_order" do
    let(:order_path) { "/commerce/v2/orders?riskInquiry=true" }
    let(:order) { { order_number: "123" } }
    let(:response_body) { { "result" => "success" } }

    before do
      allow(client_instance).to receive(:ensure_authenticated)
      client_instance.bearer_token = "dummy_token"
    end

    it "makes a POST request with correct headers and body" do
      uri = URI.join(host, order_path)
      request_double = instance_double("Net::HTTP::Post")
      response_double = instance_double("Net::HTTPResponse", body: response_body.to_json)

      expect(Net::HTTP::Post).to receive(:new).with(uri).and_return(request_double)
      expect(request_double).to receive(:[]=).with("Authorization", "Bearer dummy_token")
      expect(request_double).to receive(:[]=).with("Content-Type", "application/json")
      expect(request_double).to receive(:body=)
        .with(order.transform_keys! { |k| k.to_s.camelize(:lower) }.to_json)

      allow(Net::HTTP).to receive(:start)
        .with(uri.hostname, uri.port, use_ssl: true)
        .and_return(response_double)

      result = client_instance.post_order(order)
      expect(JSON.parse(result.body)).to eq(response_body)
    end
  end

  describe "#patch_order" do
    let(:order_id) { "123" }
    let(:order_path) { "/commerce/v2/orders/#{order_id}" }
    let(:order) { { status: "updated" } }
    let(:response_body) { { "result" => "patched" } }

    before do
      allow(client_instance).to receive(:ensure_authenticated)
      client_instance.bearer_token = "dummy_token"
    end

    it "makes a PATCH request with correct headers and body" do
      uri = URI.join(host, order_path)
      request_double = instance_double("Net::HTTP::Patch")
      response_double = instance_double("Net::HTTPResponse", body: response_body.to_json)

      expect(Net::HTTP::Patch).to receive(:new).with(uri).and_return(request_double)
      expect(request_double).to receive(:[]=).with("Authorization", "Bearer dummy_token")
      expect(request_double).to receive(:[]=).with("Content-Type", "application/json")
      expect(request_double).to receive(:body=).with(order.to_json)

      allow(Net::HTTP).to receive(:start)
        .with(uri.hostname, uri.port, use_ssl: true)
        .and_return(response_double)

      result = client_instance.patch_order(order_id, order)
      expect(JSON.parse(result.body)).to eq(response_body)
    end
  end

  describe "#create_order" do
    let(:order) do
      {
        merchant_order_id: "myOrderId",
        device_session_id: "mySess1",
        creation_date_time: "2024-03-21T10:46:22Z",
        user_ip: "163.116.253.48",
        transactions: [
          {
            payment: {
              type: "CREDIT_CARD",
              bin: "483312",
              last4: "1111"
            },
            order_total: 100,
            currency: "USD",
            billed_person: {
              name: {
                first: "Jimmy",
                last: "Jazz",
                preferred: ""
              },
              email_address: "jjazz@kount.com",
              phone_number: "+15551234567",
              address: {
                address_type: "BILLING",
                line1: "1010 Main street",
                line2: "string",
                city: "Boise",
                region: "ID",
                postal_code: "83701",
                country_code: "US"
              }
            },
            transaction_status: "PENDING"
          }
        ]
      }
    end

    let(:expected_url) { "#{host}/commerce/v2/orders?riskInquiry=true" }

    before do
      client_instance.bearer_token = "dummy_token"
    end

    context "when success" do
      let(:api_response) do
        {
          order: {
            order_id: "123",
            risk_inquiry: { decision: "APPROVE" }
          }
        }
      end

      it "is approved" do
        stub_request(:post, expected_url)
          .with(
            headers: {
              "Authorization" => "Bearer dummy_token",
              "Content-Type" => "application/json"
            },
            body: (order.deep_transform_keys! { |k| k.to_s.camelize(:lower) }).to_json
          )
          .to_return(
            status: 200,
            body: api_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = client_instance.create_order(order)
        expect(result).to be_a(Kount::Response)
        expect(result.approved?).to eq(true)
      end
    end

    context "when error" do
      let(:api_response) do
        { error: { foo: "123" } }
      end

      it "is not approved" do
        stub_request(:post, expected_url)
          .with(
            headers: {
              "Authorization" => "Bearer dummy_token",
              "Content-Type" => "application/json"
            },
            body: (order.deep_transform_keys! { |k| k.to_s.camelize(:lower) }).to_json
          )
          .to_return(
            status: 500,
            body: api_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        result = client_instance.create_order(order)
        expect(result).to be_a(Kount::Error)
        expect(result.approved?).to eq(false)
      end
    end
  end
end
