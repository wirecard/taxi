# frozen_string_literal: true

require 'logger'
require 'singleton'
require 'fileutils'

require 'taxi/config'

module Taxi
  class Log
    include Singleton

    # forward missing static method to instance
    def self.method_missing(method_name, *arguments)
      instance.send(method_name, *arguments)
    end

    def debug(msg)
      @log.debug(msg)
    end

    def info(msg)
      @log.info(msg)
    end

    def warn(msg)
      @log.warn(msg)
    end

    def error(msg)
      @log.error(msg)
    end

    def fatal(msg)
      @log.fatal(msg)
    end

    private

    def initialize
      logfile = File.join(Config.cache_dir, 'logs', 'taxi.log')
      FileUtils.mkdir_p(File.dirname(logfile))
      @log = Logger.new(logfile)
    end
  end
end
