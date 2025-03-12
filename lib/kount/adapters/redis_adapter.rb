# frozen_string_literal: true

module Kount
  module Adapters
    class RedisAdapter
      def initialize(redis_client = nil)
        @redis = redis_client
      end

      def get_token(api_key:, client:)
        key = token_key(api_key, client)
        json = @redis.get(key)
        return nil unless json

        JSON.parse(json, symbolize_names: true)
      end

      def store_token(api_key:, client:, token:, expires_in:)
        key = token_key(api_key, client)
        expiry = Time.now.to_i + expires_in
        data = { token: token, expiry: expiry }
        @redis.set(key, data.to_json, ex: expires_in)
      end

      private

      def token_key(api_key, client)
        "kount:token:#{client}:#{api_key}"
      end
    end
  end
end
