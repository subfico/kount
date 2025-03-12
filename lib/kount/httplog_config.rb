# frozen_string_literal: true

require "httplog"

module Kount
  ::HttpLog.configure do |config|
    config.enabled = true

    config.logger = Logger.new($stdout)
    config.logger_method = :log
    config.log_headers = true
  end
end
