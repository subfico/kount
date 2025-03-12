# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Kount
  class Client
    attr_accessor :api_key,
                  :client,
                  :auth_url,
                  :host,
                  :bearer_token,
                  :token_storage_adapter

    def initialize(opts)
      @api_key               = opts[:api_key]
      @client                = opts[:client]
      @auth_url              = opts[:auth_url]
      @host                  = opts[:host]
      @token_storage_adapter = opts[:token_storage_adapter]
      @bearer_token          = nil
      @token_expiry          = nil

      if token_storage_adapter &&
         !(token_storage_adapter.respond_to?(:get_token) && token_storage_adapter.respond_to?(:store_token))
        raise ArgumentError, "Token storage adapter must implement get_token and store_token methods"
      end
    end

    def create_order(order, risk_inquiry: true)
      response_handler do
        post_order(order, risk_inquiry)
      end
    end

    def update_order(order_id, order)
      response_handler do
        patch_order(order_id, order)
      end
    end

    private

    def authenticate
      if token_storage_adapter
        cached = token_storage_adapter.get_token(api_key: api_key, client: client)
        if cached && !token_expired?(cached)
          @bearer_token = cached[:token]
          @token_expiry = cached[:expiry]
          return @bearer_token
        end
      end

      uri = URI.parse(auth_url)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Basic #{api_key}"
      request["Content-Type"]  = "application/x-www-form-urlencoded"

      form_data = URI.encode_www_form(
        grant_type: "client_credentials",
        scope: "k1_integration_api"
      )
      request.body = form_data

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      raise "Authentication failed (#{response.code}): #{response.body}" unless response.code.to_i == 200

      data = JSON.parse(response.body)
      @bearer_token = data["access_token"]

      # Subtract a safety margin (e.g. 120 seconds) so we re-authenticate early.
      expires_in = data["expires_in"] || 3600
      effective_expires_in = expires_in - 120
      @token_expiry = Time.now.to_i + effective_expires_in

      token_storage_adapter&.store_token(
        api_key: api_key,
        client: client,
        token: @bearer_token,
        expires_in: effective_expires_in
      )

      @bearer_token
    end

    def response_handler
      response = yield
      body = JSON.parse(response.body)
      body.deep_transform_keys!(&:underscore)

      if response.code == "200"
        Response.new(body)
      else
        Error.new(body)
      end
    end

    def post_order(order, risk_inquiry)
      ensure_authenticated
      uri = URI.parse("#{host}/commerce/v2/orders?riskInquiry=#{risk_inquiry}")
      headers = {
        "Authorization" => "Bearer #{bearer_token}",
        "Content-Type" => "application/json"
      }
      transformed_order = order.deep_transform_keys { |k| k.to_s.camelize(:lower) }
      send_request(Net::HTTP::Post, uri, headers, transformed_order.to_json)
    end

    def patch_order(order_id, order)
      ensure_authenticated
      uri = URI.parse("#{host}/commerce/v2/orders/#{order_id}")
      headers = {
        "Authorization" => "Bearer #{bearer_token}",
        "Content-Type" => "application/json"
      }
      transformed_order = order.deep_transform_keys { |k| k.to_s.camelize(:lower) }
      send_request(Net::HTTP::Patch, uri, headers, transformed_order.to_json)
    end

    def ensure_authenticated
      return unless bearer_token.nil? || (@token_expiry && Time.now.to_i >= @token_expiry)

      authenticate
    end

    def token_expired?(cached_token)
      expiry = cached_token[:expiry]
      Time.now.to_i >= expiry
    end

    def send_request(http_method_class, uri, headers = {}, body = nil)
      request = http_method_class.new(uri)
      headers.each { |key, value| request[key] = value }
      request.body = body if body
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
    end
  end
end
