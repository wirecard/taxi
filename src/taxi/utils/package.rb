# frozen_string_literal: true

require 'taxi/config'

module Taxi
  module Utils
    def self.folder_structure(package_name, from: 'en_US', to: nil)
      packages = Dir.glob("#{package_name}-*", base: Config.cache_dir)
      # TODO is the first package always the newest?
      pkg = packages.first
      basename = File.basename(pkg, '.tar.gz')
      name, date = basename.split('-')
      # return folder structure as array
      # consists of "<name>/ru_RU/20200426".split('/')
      return [name, to, date]
    end

    def self.dated_package_name(name)
      today = Date.today.strftime('%Y%m%d')
      "#{name}-#{today}"
    end
  end
end
