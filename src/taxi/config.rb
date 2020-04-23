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

      puts '* S3 Buckets'.blue
      ap aws_s3_client.list_buckets
    end

    def aws_s3_client
      # Create Role Credentials with AssumeRole ARN
      role_response = Aws::AssumeRoleCredentials.new(
        client: @aws_sts_client,
        role_arn: @aws_config.role_assume,
        role_session_name: 'github://wirecard/taxi',
        duration_seconds: 1200,
        tags: [
          {
            key: 'client',
            value: 'TAXI',
          },
          {
            key: 'repository',
            value: 'wirecard/taxi',
          },
          {
            key: 'team',
            value:'tecdoc',
          },
        ],
        endpoint: @aws_config.endpoint_url
      )

      # role_response = @aws_sts_client.assume_role(
      #   role_arn: @aws_config.role_assume,
      #   role_session_name: 'github://wirecard/taxi',
      #   duration_seconds: 1200,
      #   tags: [
      #     {
      #       key: 'client',
      #       value: 'TAXI',
      #     },
      #     {
      #       key: 'repository',
      #       value: 'wirecard/taxi',
      #     },
      #     {
      #       key: 'team',
      #       value:'tecdoc',
      #     },
      #   ],
      #   endpoint: @aws_config.endpoint_url
      # )

      # Use AssumeRole Credentials to create S3 Client
      return Aws::S3::Client(
        credentials: role_response.credentials,
        region: @aws_config.region
      )
    end

    private

    def initialize
      aws_config = {
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
        region: ENV['AWS_REGION'],
        role_assume: ENV['AWS_ROLE_TO_ASSUME'],
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
