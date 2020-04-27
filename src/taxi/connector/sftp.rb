require 'net/sftp'

module Taxi
  class SFTP
    def list_dir(path = '/')
      @sftp.dir.foreach(path) do |element|
        pp element
      end
    end

    private

    def initialize
      sftp_config = ::Taxi::Config.sftp_config
      @sftp = Net::SFTP.start(
        sftp_config.host + ':' + sftp_config.port, sftp_config.user,
        key_data: [sftp_config.key],
        keys: [],
        keys_only: true
      )
    end
  end
end
