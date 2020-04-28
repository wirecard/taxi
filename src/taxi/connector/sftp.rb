# frozen_string_literal: true

require 'net/sftp'
require 'progressbar'

require 'taxi/utils/log'

module Taxi
  class SFTP
    include Singleton

    # forward missing static method to instance
    def self.method_missing(method_name, *arguments)
      instance.send(method_name, *arguments)
    end

    def ls(path = '/')
      @sftp.dir.foreach(path) do |element|
        puts element.longname
      end
    end

    def upload(src, dst, base = File.join('/share', DirConfig::OPEN))
      Log.info("SFTP Upload src=#{src} base=#{base} dst=#{dst}")
      puts '> SFTP Upload'.green
      puts "              BASE = #{base.blueish}".blue
      puts "              DST  = #{dst.blueish}".blue
      # package folder setup on remote
      current = base
      dst.split('/') do |dir|
        current = File.join(current, dir)
        create_dir(current) unless exists?(current)
      end

      files = Dir.glob('**/*', base: src)
      progressbar = ProgressBar.create(
        title: '  SFTP:upload'.green,
        total: files.size
      )
      # copy package
      files.each do |entry|
        # create remote path
        local = File.join(src, entry)
        remote = File.join(base, dst, entry)
        Log.debug("Uploading #{entry}")
        # create dir if necessary
        if File.directory?(local)
          create_dir(remote) unless exists?(remote)
        else
          # upload if entry is a file
          @sftp.upload!(local, remote)
        end

        progressbar.increment
      end
      progressbar.finish unless progressbar.finished?
      puts '> SFTP Upload finished'.green
      puts '> SFTP Translate finished'.green
    end

    private

    def exists?(path)
      dirname = File.dirname(path)
      basename = File.basename(path)
      return @sftp.dir.entries(dirname).map(&:name).include?(basename)
    rescue Net::SFTP::StatusException
      return false
    end

    def create_dir(path)
      Log.debug("Creating  #{path}")
      @sftp.mkdir!(path)
    end

    def checks
      create_dir('/share') unless exists?('/share')

      subdirs = [
        DirConfig::OPEN, DirConfig::REVIEW, DirConfig::DEPLOY, DirConfig::DONE
      ].map { |dir| File.join('/share', dir) }

      subdirs.each do |subdir|
        create_dir(subdir) unless exists?(subdir)
      end
    end

    def initialize
      sftp_config = Config.sftp_config
      options = {
        port: sftp_config.port,
        keys: sftp_config.keys,
        keys_only: true,
        use_agent: false
      }
      options[:user_known_hosts_file] = '/dev/null' if ENV.key?('DEV_ENV')
      options[:verbose] = ENV['LOGLEVEL']&.to_sym || :error
      @sftp = Net::SFTP.start(sftp_config.host, sftp_config.user, options)
      # sanity checks
      checks
    end
  end
end
