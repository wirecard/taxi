require 'net/sftp'

module Taxi
  class SFTP
    include Singleton

    def file_download(src, dest)
      File.write(dest, file_get_data(src))
    end

    def file_upload(src, dest)
      create_dir(dest)
      # not used path.join as we always need '/' on sftp as separator
      remote_filepath = dest + '/' + File.basename(src)
      file_put_data(remote_filepath, File.read(src))
    end

    def file_exists?(path)
      dirname = File.dirname(path)
      filename = File.basename(path)
      return list_dir(dirname).include? filename
    end

    def create_dir(remote_dir)
      dir = []
      remote_dir.split('/').foreach do |part|
        dir << part
        @sftp.mkdir(dir.join('/')).wait
      end
    end

    def ls(path = '/')
      @sftp.dir.foreach(path) do |element|
        puts element.longname
      end
    end

    def file_get_data(path)
      @sftp.download!(path)
    end

    def file_put_data(path, data)
      if file_exists?(path)
        puts "file #{path} exists. skipping"
      else
        dir = File.dirname(path)
        create_dir(dir)
        @sftp.file.open(path, 'w') do |file|
          file.puts data
        end
      end
    end

    private

    def initialize
      sftp_config = Config.sftp_config
      options = {
        port: sftp_config.port,
        keys: sftp_config.keys,
        keys_only: true,
        use_agent: false,
      }
      options[:user_known_hosts_file] = '/dev/null' if ENV.key?('DEV_ENV')
      options[:verbose] = ENV['LOGLEVEL']&.to_sym || :error
      @sftp = Net::SFTP.start(sftp_config.host, sftp_config.user, options)
    rescue Net::SFTP::StatusException => e
      pp e
    end
  end
end
