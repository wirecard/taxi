# frozen_string_literal: true
require 'taxi/config'
require 'taxi/connector/aws'
require 'taxi/connector/sftp'
require 'taxi/utils/compression'
require 'taxi/utils/package'

module Taxi
  module Package
    def self.make(name, path, bucket: ENV['AWS_DEFAULT_BUCKET'])
      Log.info("called package make: name=#{name} path=#{path} bucket=#{bucket}")
      package_name = Utils.dated_package_name(name)
      location = "s3://#{bucket}/#{path}" # "#{path}@#{bucket}"
      puts "> Create package #{package_name.blue} <- #{location.blueish}".yellow
      Dir.mktmpdir do |dir|
        ::Taxi::S3.download(bucket, path, dir)

        file_path = File.join(
          Config.cache_dir,
          "#{package_name}.tar.gz"
        )

        puts "> Creating package #{package_name.blue}".green
        download_dir = File.join(dir, path)
        Dir.chdir(download_dir) do
          Compression.targz('.', file_path)
        end
        puts "> Package created: #{package_name.blue}".green
      end
    end

    def self.translate(name, from: DEFAULT_LANGUAGE, to: DEFAULT_LANGUAGE, agency: nil)
      puts '> SFTP translate'.blue

      local_package = Utils.get_latest_package(name)
      date = File.basename(local_package, '.tar.gz').split('-').last
      remote_package = Utils.get_package_name(name, from: from, to: to, timestamp: date)
      package_path = Config.cache_dir(local_package)

      puts "> Package: #{local_package.white} -> #{remote_package.white}".blue
      Dir.mktmpdir do |dir|
        Log.info("targz unpack: #{local_package} -> #{dir}")
        Compression.untargz(package_path, dir)

        sftp = ::Taxi::SFTP.new(agency)
        sftp.remove(remote_package)
        sftp.upload(dir, remote_package)
      end
    end

    def self.deploy(
      name, path, from: DEFAULT_LANGUAGE, to: DEFAULT_LANGUAGE,
      agency: nil, bucket: nil
    )
      puts '! Deploy'.green
      # package_name = Utils.get_package_name(name, from: from, to: to)
      sftp = ::Taxi::SFTP.new(agency)
      packages = sftp.glob(
        File.join('/', DirConfig::DEPLOY),
        "#{name}-*"
      ).map(&:name)
      package_name = packages.max # TODO this will only deploy last translation

      if package_name.nil?
        raise FileNotFound.new(
          "No folder like '#{name}-*' in #{DirConfig::DEPLOY}")
      end

      sftp.download(package_name)

      subdir = Config.cache_dir(DirConfig::DEPLOY.split('_').last)
      local_dir = File.join(subdir, package_name)
      remote_dir = File.join(path, to.split('_').first)

      # delete the subfolder if it exists
      if ::Taxi::S3.dir_exists?(bucket, remote_dir)
        puts '> AWS Cleanup'.yellow
        ::Taxi::S3.delete(bucket, remote_dir)
      end

      puts '> AWS Deploy'.yellow
      ::Taxi::S3.upload(bucket, local_dir, remote_dir)
      puts '> AWS Deploy Done'.green

      puts "> SFTP Archive Packages".blue
      # move all packages that match the glob "name-*"
      packages.each do |pkg|
        sftp.move(
          File.join('/', DirConfig::DEPLOY, pkg),
          File.join('/', DirConfig::DONE, pkg)
        )
      end
    end
  end
end
