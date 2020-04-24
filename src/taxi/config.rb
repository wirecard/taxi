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

    def list_buckets
      puts '* AWS Buckets'.yellow
      s3 = aws_s3_client
      ap s3.list_buckets
    end

    def aws_assume_role
      # Create Role Credentials with AssumeRole ARN
      Aws::AssumeRoleCredentials.new(
        client: @aws_sts_client,
        role_arn: @aws_config.role_assume,
        role_session_name: 'github://wirecard/taxi',
        duration_seconds: 1200,
        tags: [
          {
            key: 'client',
            value: 'TAXI'
          },
          {
            key: 'repository',
            value: 'wirecard/taxi'
          },
          {
            key: 'team',
            value:'tecdoc'
          }
        ],
        endpoint: @aws_config.endpoint_url
      )
    end

    def aws_s3_client
      role_response = aws_assume_role
      # Use AssumeRole Credentials to create S3 Client
      Aws::S3::Client.new(credentials: role_response.credentials)
    end

    private

    def initialize
      aws_config = {
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
        region: ENV['AWS_REGION'],
        role_assume: ENV['AWS_ROLE_TO_ASSUME'],
        endpoint_url: ENV['AWS_ENDPOINT_URL'],
        signature_version: ENV['AWS_SIGNATURE_VERSION']&.to_sym || :v2
      }
      @aws_config = OpenStruct.new(aws_config)

      sftp_config = {
        user: ENV['SFTP_USER'],
        host: ENV['SFTP_HOST'],
        port: ENV['SFTP_PORT'],
        key: ENV['SFTP_KEY']
      }
      @sftp_config = OpenStruct.new(sftp_config)

      Aws.config.update(
        endpoint: @aws_config.endpoint_url,
        access_key_id: @aws_config.access_key_id,
        secret_access_key: @aws_config.secret_access_key,
        region: @aws_config.region
      )
      Aws.use_bundled_cert!

      # @aws_credentials = Aws::Credentials.new
      @aws_sts_client = Aws::STS::Client.new
    end
  end
end
