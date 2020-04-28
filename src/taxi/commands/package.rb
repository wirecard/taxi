# frozen_string_literal: true
require 'taxi/config'
require 'taxi/connector/aws'
require 'taxi/connector/sftp'
require 'taxi/utils/compression'
require 'taxi/utils/package'

module Taxi
  module Package
    def self.make(bucket)
      Dir.mktmpdir do |dir|
        ::Taxi::S3.download(bucket, dir)

        package_name = Utils.dated_package_name(bucket)
        file_path = File.join(
          Config.cache_dir,
          "#{package_name}.tar.gz"
        )

        Dir.chdir(dir) do
          Compression.targz('.', file_path)
        end
        puts "> Package created: #{package_name.blue}".green
      end
    end

    def self.translate(name, language_code)
      puts '> SFTP translate'.blue

      name, lang, date = Utils.folder_structure(name, to: language_code)
      folders = File.join(name, lang, date)
      package = Utils.get_latest_package(name)
      package_path = Config.cache_dir(package)

      puts "> Package: #{folders.blue}".green
      Dir.mktmpdir do |dir|
        Log.info("targz unpack: #{package} -> #{dir}")
        Compression.untargz(package_path, dir)

        ::Taxi::SFTP.upload(dir, folders)
      end
    end
  end
end
