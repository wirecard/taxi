# frozen_string_literal: true

require 'net/sftp'
require 'progressbar'
require 'fileutils'

require 'taxi/utils/log'
require 'taxi/utils/progressbar'

module Taxi
  class SFTP
    # forward missing static method to instance
    def self.method_missing(method_name, *arguments)
      instance.send(method_name, *arguments)
    end

    def ls(path = '/')
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

    def glob(path, pattern)
      dirlist = []
      @sftp.dir.glob(path, pattern) do |match|
        dirlist << match
      end
      return dirlist
    end

    def move_glob(name, from, to)
      packages = @sftp.dir.glob(
        from, "#{name}-*"
      ).map(&:name)
      packages.each do |pkg|
        move(File.join(from, pkg), File.join(to, pkg))
        remove(pkg, path: from, include_parent: true)
      end
    end

    def move(from, to)
      puts "> SFTP rename: #{from.whiteish} -> #{to.whiteish}".blue
      begin
        @sftp.rename!(from, to)
      rescue Net::SFTP::StatusException => ex
        # manual rename
        puts ">>> SFTP manual rename".blue
        file_list = get_file_list(from)
        progressbar = ProgressBar.create(
          title: '  SFTP:rename'.purple, total: file_list.size)
        file_list.each do |entry|
          file_from = File.join(from, entry.name)
          file_to = File.join(to, entry.name)
          if entry.directory?
            @sftp.mkdir(file_to)
          else
            @sftp.rename!(file_from, file_to)
          end
          progressbar.increment
        end
        progressbar.finish unless progressbar.finished?
      end
    end

    def remove(dir, path: DirConfig::OPEN, include_parent: false)
      cpath = (path.nil?) ? dir : File.join(path, dir)

      begin
        file_list = get_file_list(cpath)
      rescue Net::SFTP::StatusException => status_ex
        return if status_ex.code == 2

        raise status_ex
      end

      puts '> SFTP Remove started'.purple

      progressbar = ProgressBar.create(
        title: '  SFTP:remove'.purple, total: file_list.size)
      file_list.each do |entry|
        fpath = File.join(cpath, entry.name)
        Log.debug("remove remote://#{fpath}")
        entry.directory? ? @sftp.rmdir!(fpath) : @sftp.remove(fpath)
        progressbar.increment
      end
      @sftp.rmdir!(cpath) if include_parent
      puts '> SFTP Remove finished'.purple
    end

    def download(package, category: DirConfig::DEPLOY)
      Log.info("SFTP Download #{package}")

      remote_dir = category
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
        puts '> SFTP Query: getting file index...'.blue
        @sftp.dir.glob(remote_path, '**/*') { |file| files << file }
        # add 1 to size because the download counts the current directory,
        # unlike the glob operation
        progress = Utils::ProgressBarHandler
          .new('  SFTP:download'.blue, files.size + 1)
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

    def upload(src, dst, base = DirConfig::OPEN)
      Log.info("SFTP Upload src=#{src} base=#{base} dst=#{dst}")
      puts '> SFTP Upload'.blue
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
        title: '  SFTP:upload'.blue,
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

    def exists?(path)
      dirname = File.dirname(path)
      basename = File.basename(path)
      return @sftp.dir.entries(dirname).map(&:name).include?(basename)
    rescue Net::SFTP::StatusException
      return false
    end

    private

    def get_file_list(path)
      file_list = []
      @sftp.dir.glob(path, '**/*') { |entry| file_list << entry }
      file_list.sort! { |a,b| b.name.count('/') <=> a.name.count('/') }
      return file_list
    end

    def create_dir(path)
      Log.debug("Creating  #{path}")
      @sftp.mkdir!(path)
    end

    def checks
      subdirs = [
        DirConfig::OPEN, DirConfig::DEPLOY, DirConfig::DONE
      ]

      subdirs.each do |subdir|
        create_dir(subdir) unless exists?(subdir)
      end
    end

    def initialize(user)
      sftp_config = Config.sftp_config
      user_keys_dir = File.join(sftp_config.keys, user)
      unless File.exists?(user_keys_dir)
        raise SFTPError, "No keys for user #{user} found @ #{user_keys_dir}"
      end

      options = {
        port: sftp_config.port,
        keys: Dir.glob(File.join(user_keys_dir, '*?[^(\.pub)]')),
        keys_only: true,
        use_agent: false
      }
      options[:user_known_hosts_file] = '/dev/null' if ENV.key?('DEV_ENV')
      options[:verbose] = ENV['LOGLEVEL']&.to_sym || :error
      @sftp = Net::SFTP.start(sftp_config.host, user, options)
      checks
    end

  end
end
