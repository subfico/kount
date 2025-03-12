# frozen_string_literal: true

module Kount
  class AbstractResponse
    def to_hash
      raise "Not implemented"
    end

    def ok?
      raise "Not implemented"
    end

    def approved?
      raise "Not implemented"
    end
  end
end
