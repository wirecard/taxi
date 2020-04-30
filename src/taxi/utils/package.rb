# frozen_string_literal: true

require 'taxi/config'

module Taxi
  module Utils
    # DEPRECATED
    def self.folder_structure(pkg_name, from: 'en_US', to: nil)
      pkg = get_latest_package(pkg_name)
      basename = File.basename(pkg, '.tar.gz')
      name, date = basename.split('-')
      # return folder structure as array
      # consists of "<name>/ru_RU/20200426".split('/')
      return [name, to, date]
    end

    def self.get_package_name(name, from: 'en_US', to: 'en_US')
      return "#{name}-#{from}-#{to}"
    end

    def self.get_latest_package(pkg_name)
      packages = Dir.glob("#{pkg_name}-*", base: Config.cache_dir)
      # TODO is the first package always the newest?
      return packages.max # same as .sort.last
    end

    def self.dated_package_name(pkg_name)
      today = Date.today.strftime('%Y%m%d')
      "#{pkg_name}-#{today}"
    end
  end
end
