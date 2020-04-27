require 'net/sftp'

module Taxi
  class SFTP
    include Singleton

    def file_download(src, dest)
      File.write(dest, file_get_data(src))
    end

    def file_upload(src, dest)
      file_put_data(dest, File.read(src))
    end

    def file_exists?(path)
      dirname = File.dirname(path)
      filename = File.basename(path)
      return list_dir(dirname).include? filename
    end

    def create_dir(path)
      
    end

    def list_dir(path = '/')
      @sftp.dir.foreach(path) do |element|
        pp element
      end
    end

    def file_get_data(path)
      begin
        data = @sftp.download!(path)
      rescue Net::SFTP::StatusException => e
        pp e
      end
      return data
    end

    def file_put_data(path, data)
      if file_exists?(path)
        puts "file #{path} exists. skipping"
      else
        begin
          @sftp.file.open(path, 'w') do |file|
            file.puts data
          end
        rescue Net::SFTP::StatusException => e
          pp e
        end
        return file_exists?(path)
      end
    end

    private

    def initialize
      sftp_config = ::Taxi::Config.sftp_config
      begin
        @sftp = Net::SFTP.start(
          sftp_config.host + ':' + sftp_config.port, sftp_config.user,
          key_data: [sftp_config.key],
          keys: [],
          keys_only: true
        )
      rescue Net::SFTP::StatusException => e
        pp e
      end
    end
  end
end
