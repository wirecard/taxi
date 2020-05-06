# frozen_string_literal: true

require 'taxi/config'

module Taxi
  module Utils
    def self.get_package_name(
      name,
      from: DEFAULT_LANGUAGE, to: DEFAULT_LANGUAGE, timestamp: nil
    )
      if timestamp.nil?
        return "#{name}-#{from}-#{to}"
      else
        return "#{name}-#{from}-#{to}-#{timestamp}"
      end
    end

    def self.get_latest_package(pkg_name)
      packages = Dir.glob("#{pkg_name}-*.tar.gz", base: Config.cache_dir)
      return packages.max # same as .sort.last
    end

    def self.dated_package_name(pkg_name)
      today = Date.today.strftime('%Y%m%d')
      "#{pkg_name}-#{today}"
    end
  end
end
