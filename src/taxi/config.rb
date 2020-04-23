# frozen_string_literal: true

require 'singleton'
require 'ostruct'
require 'dotenv'
require 'amazing_print'

class Config
  include Singleton

  attr_reader :aws_config, :sftp_config

  # Outputs currently loaded config.
  def print
    puts '+ AWS Config'.yellow
    ap @aws_config
    puts '+ SFTP Config'.blue
    ap @sftp_config
  end

  private

  def initialize
    Dotenv.load if ENV.key?('DEV_ENV')

    aws_config = {
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
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
  end
end
