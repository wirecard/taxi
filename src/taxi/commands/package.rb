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

        puts "> Creating package #{package_name.blue}".green
        Dir.chdir(dir) do
          Compression.targz('.', file_path)
        end
        puts "> Package created: #{package_name.blue}".green
      end
    end

    def self.translate(name, from: DEFAULT_LANGUAGE, to: DEFAULT_LANGUAGE)
      puts '> SFTP translate'.blue

      local_package = Utils.get_latest_package(name)
      date = File.basename(local_package, '.tar.gz').split('-').last
      remote_package = Utils.get_package_name(name, from: from, to: to, timestamp: date)
      package_path = Config.cache_dir(local_package)

      puts "> Package: #{local_package.white} -> #{remote_package.white}".blue
      Dir.mktmpdir do |dir|
        Log.info("targz unpack: #{local_package} -> #{dir}")
        Compression.untargz(package_path, dir)

        ::Taxi::SFTP.remove(remote_package)
        ::Taxi::SFTP.upload(dir, remote_package)
      end
    end

    def self.deploy(name, from: DEFAULT_LANGUAGE, to: DEFAULT_LANGUAGE)
      puts '! Deploy'.green
      # package_name = Utils.get_package_name(name, from: from, to: to)
      package_name = ::Taxi::SFTP.glob(
        File.join('/share', DirConfig::DEPLOY),
        "#{name}-*"
      ).map(&:name).max

      if package_name.nil?
        raise FileNotFound.new(
          "No folder like '#{name}-*' in #{DirConfig::DEPLOY}")
      end

      ::Taxi::SFTP.download(package_name)

      subdir = Config.cache_dir(DirConfig::DEPLOY.split('_').last)
      local_dir = File.join(subdir, package_name)
      lang_code = to.split('_').first

      # delete the subfolder if it exists
      if ::Taxi::S3.dir_exists?(name, lang_code)
        puts '> AWS Cleanup'.yellow
        ::Taxi::S3.delete(name, lang_code)
      end

      puts '> AWS Deploy'.yellow
      ::Taxi::S3.upload(name, local_dir, lang_code)
      puts '> AWS Deploy Done'.green

      puts "> SFTP Archive Package #{package_name.white}".blue
      ::Taxi::SFTP.move(
        File.join('/share', DirConfig::DEPLOY, package_name),
        File.join('/share', DirConfig::DONE, package_name)
      )
    end
  end
end
