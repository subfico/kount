# frozen_string_literal: true

module Kount
  class Response < AbstractResponse
    attr_accessor :order_id, :merchant_order_id, :channel,
                  :device_session_id, :creation_date_time,
                  :risk_inquiry, :transactions, :fulfillment

    def initialize(data)
      @data = data

      if (order = @data["order"])
        @order_id           = order["order_id"]
        @merchant_order_id  = order["merchant_order_id"]
        @channel            = order["channel"]
        @device_session_id  = order["device_session_id"]
        @creation_date_time = order["creation_date_time"]
        @risk_inquiry       = RiskInquiry.new(order["risk_inquiry"] || {})
        @transactions       = (order["transactions"] || []).map { |t| Transaction.new(t) }
      else
        @data
      end
    end

    def to_hash
      @data
    end

    def ok?
      true
    end

    def approved?
      !!@risk_inquiry&.approved?
    end
  end

  class RiskInquiry
    attr_accessor :decision, :omniscore, :persona, :device, :segment_executed

    def initialize(attrs = {})
      @decision = attrs["decision"]
      @omniscore = attrs["omniscore"]
      @persona = Persona.new(attrs["persona"] || {})
      @device = attrs["device"]
      @segment_executed = SegmentExecuted.new(attrs["segment_executed"] || {})
    end

    def approved?
      @decision == "APPROVE"
    end
  end

  class Persona
    attr_accessor :unique_cards, :unique_devices, :unique_emails

    def initialize(attrs = {})
      @unique_cards = attrs["unique_cards"]
      @unique_devices = attrs["unique_devices"]
      @unique_emails = attrs["unique_emails"]
    end
  end

  class SegmentExecuted
    attr_accessor :segment, :policies_executed, :tags

    def initialize(attrs = {})
      @segment = Segment.new(attrs["segment"] || {})
      @policies_executed = attrs["policies_executed"] || []
      @tags = attrs["tags"] || []
    end
  end

  class Segment
    attr_accessor :id, :name, :priority

    def initialize(attrs = {})
      @id = attrs["id"]
      @name = attrs["name"]
      @priority = attrs["priority"]
    end
  end

  class Transaction
    attr_accessor :transaction_id, :merchant_transaction_id

    def initialize(attrs = {})
      @transaction_id = attrs["transaction_id"]
      @merchant_transaction_id = attrs["merchant_transaction_id"]
    end
  end
end
