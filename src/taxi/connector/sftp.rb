# frozen_string_literal: true

require 'net/sftp'
require 'progressbar'
require 'fileutils'

require 'taxi/utils/log'
require 'taxi/utils/progressbar'

module Taxi
  class SFTP
    include Singleton

    # forward missing static method to instance
    def self.method_missing(method_name, *arguments)
      instance.send(method_name, *arguments)
    end

    def ls(path = '/share')
      dirlist = []
      @sftp.dir.foreach(path) do |element|
        dirlist << element
      end
      return dirlist
    end

    def print_ls(path)
      elements = ls(path)
      elements.each do |e|
        puts e.longname
      end
    end

    def move(from, to)
      puts "> SFTP rename: #{from} -> #{to}".blue
      @sftp.rename!(from, to)
    end

    def remove(dir, category: DirConfig::OPEN, path: File.join('/share', category))
      cpath = File.join(path, dir)

      begin
        file_list = []
        @sftp.dir.glob(cpath, '**/*') do |entry|
          file_list << entry
        end
      rescue Net::SFTP::StatusException => status_ex
        return if status_ex.code == 2

        raise status_ex
      end

      puts '> SFTP Remove started'.purple
      file_list.sort! { |a,b| b.name.count('/') <=> a.name.count('/') }

      progressbar = ProgressBar.create(
        title: '  SFTP:remove'.purple, total: file_list.size)
      file_list.each do |entry|
        fpath = File.join(cpath, entry.name)
        Log.debug("remove remote://#{fpath}")
        entry.directory? ? @sftp.rmdir!(fpath) : @sftp.remove(fpath)
        progressbar.increment
      end
      puts '> SFTP Remove finished'.purple
    end

    def download(package, category: DirConfig::DEPLOY)
      Log.info("SFTP Download #{package}")

      remote_dir = File.join('/share', category)
      local_dir = Config.cache_dir('deploy')

      puts '> SFTP Download'.blue
      puts "                DOWNLOAD FOLDER = #{local_dir}".blue
      puts "                PACKAGE = #{package}".blue

      remote_path = File.join(remote_dir, package)
      local_path = File.join(local_dir, package)
      FileUtils.rm_r(local_path) if Dir.exists?(local_path)
      FileUtils.mkdir_p(local_path)

      begin
        files = []
        puts '> SFTP Query: getting file index...'.green
        @sftp.dir.glob(remote_path, '**/*') { |file| files << file }
        # add 1 to size because the download counts the current directory,
        # unlike the glob operation
        progress = Utils::ProgressBarHandler
          .new('  SFTP:download'.green, files.size + 1)
        options = { recursive: true, progress: progress }
        @sftp.download!(remote_path, local_path, options)
      rescue Net::SFTP::StatusException => e
        if e.code == 2
          puts '! ERROR'.red
          puts e.message.red
          abort "Error: #{e.message}"
        end
        raise e
      end

      puts '> SFTP Download finished'.green
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
        DirConfig::OPEN, DirConfig::DEPLOY, DirConfig::DONE
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
