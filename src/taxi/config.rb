# frozen_string_literal: true

require 'singleton'
require 'ostruct'
require 'amazing_print'
require 'aws-sdk-s3'

module Taxi
  class Config
    include Singleton

    attr_reader :aws_config, :sftp_config, :aws_credentials

    # Outputs currently loaded config.
    def print
      puts '+ SFTP Config'.blue
      ap @sftp_config
      puts '+ AWS Config'.yellow
      ap @aws_config
    end

    private

    def initialize
      aws_config = {
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
        region: ENV['AWS_REGION'],
        endpoint_url: ENV['AWS_ENDPOINT_URL']
      }
      @aws_config = OpenStruct.new(aws_config)

      sftp_config = {
        user: ENV['SFTP_USER'],
        host: ENV['SFTP_HOST'],
        port: ENV['SFTP_PORT'],
        key: ENV['SFTP_KEY']
      }
      @sftp_config = OpenStruct.new(sftp_config)

      @aws_credentials = Aws::Credentials.new(
        @aws_config.access_key_id, @aws_config.secret_access_key
      )

      @aws_sts_client = Aws::STS::Client.new(
        region: @aws_config.region,
        credentials: @aws_credentials
      )
    end
  end
end
