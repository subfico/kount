# frozen_string_literal: true

module Kount
  class Error < AbstractResponse
    attr_reader :data

    def initialize(data)
      @data = data
    end

    def to_hash
      @data
    end

    def ok?
      false
    end

    def approved?
      false
    end
  end
end
