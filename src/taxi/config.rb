# frozen_string_literal: true

require 'singleton'
require 'ostruct'
require 'amazing_print'
require 'aws-sdk-s3'
require 'fileutils'

require 'taxi/errors'

module Taxi
  DEFAULT_LANGUAGE = 'en_US'

  module DirConfig
    OPEN = '1_open'
    DEPLOY = '2_deploy'
    DONE = '3_done'
  end

  class Config
    include Singleton

    attr_reader :aws_config, :sftp_config, :agencies

    # forward missing static method to instance
    def self.method_missing(method_name, *arguments)
      instance.send(method_name, *arguments)
    end

    def cache_dir(file = nil)
      FileUtils.mkdir_p(@cache_dir)
      if file.nil?
        @cache_dir
      else
        File.join(@cache_dir, file)
      end
    end

    # Outputs currently loaded config.
    def print
      puts '+ SFTP Config'.blue
      ap @sftp_config
      puts '+ AWS Config'.yellow
      ap @aws_config

      puts '= AWS Settings (updated)'.yellow
      ap Aws.config

      puts '? Misc'.cyan
      puts "Cache dir: #{@cache_dir.redish}"
    end

    private

    def initialize
      aws_config = {
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
        region: ENV['AWS_DEFAULT_REGION'],
        role_assume: ENV['AWS_ROLE_TO_ASSUME'],
        signature_version: ENV['AWS_SIGNATURE_VERSION']&.to_sym || :v2
      }
      aws_config[:endpoint_url] = ENV['AWS_ENDPOINT_URL'] if ENV.key?('AWS_ENDPOINT_URL')

      @aws_config = OpenStruct.new(aws_config)

      Aws.config.update(
        access_key_id: @aws_config.access_key_id,
        secret_access_key: @aws_config.secret_access_key,
        region: @aws_config.region
      )
      Aws.config.update(
        endpoint: @aws_config.endpoint_url
      ) if aws_config.key?(:endpoint_url)
      Aws.use_bundled_cert!

      sftp_config = {
        user: ENV['SFTP_USER'],
        host: ENV['SFTP_HOST'],
        port: ENV['SFTP_PORT'],
        keys: ENV['SFTP_KEYS']
      }
      @sftp_config = OpenStruct.new(sftp_config)

      @cache_dir = File.expand_path(ENV['TAXI_CACHE']) || File.join(Dir.tmpdir, 'taxi', 'cache')

      @agencies = {
        'agency1': {
          folder: 'agency1',
          name: 'Translatio Imperii'
        },
        'agency2': {
          folder: 'agency2',
          name: 'Russkaja'
        },
        'agency3': {
          folder: 'agency3',
          name: 'اَلْعَرَبِيَّةُ'
        }
      }
      @agencies = OpenStruct.new(agencies)
    end
  end
end
