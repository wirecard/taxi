# frozen_string_literal: true
require 'taxi/config'
require 'taxi/connector/aws'
require 'taxi/connector/sftp'
require 'taxi/utils/compression'
require 'taxi/utils/package'

module Taxi
  DEFAULT_LANGUAGE = 'en_US'
  module Package
    def self.make(bucket)
      Dir.mktmpdir do |dir|
        ::Taxi::S3.download(bucket, dir)

        package_name = Utils.dated_package_name(bucket)
        file_path = File.join(
          Config.cache_dir,
          "#{package_name}.tar.gz"
        )

        puts "> Creating package #{package_name.blue}".green
        Dir.chdir(dir) do
          Compression.targz('.', file_path)
        end
        puts "> Package created: #{package_name.blue}".green
      end
    end

    def self.translate(name, from: DEFAULT_LANGUAGE, to: DEFAULT_LANGUAGE)
      puts '> SFTP translate'.blue

      remote_package = Utils.get_package_name(name, to: to)
      local_package = Utils.get_latest_package(name)
      package_path = Config.cache_dir(local_package)

      puts "> Package: #{local_package.blue} -> #{remote_package.blue}".green
      Dir.mktmpdir do |dir|
        Log.info("targz unpack: #{local_package} -> #{dir}")
        Compression.untargz(package_path, dir)

        ::Taxi::SFTP.remove(remote_package)
        ::Taxi::SFTP.upload(dir, remote_package)
      end
    end

    def self.review_inspect(name, from: DEFAULT_LANGUAGE, to: DEFAULT_LANGUAGE)
      ::Taxi::SFTP.download(name, from: from, to: to)
    end
  end
end
