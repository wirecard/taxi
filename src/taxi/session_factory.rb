# frozen_string_literal: true

require 'singleton'
require 'aws-sdk-s3'

module Taxi
  class SessionFactory
    include Singleton
    def create_S3_session(bucket)
    end

    def create_sftp_session
    end

    private

    def initialize
    end
  end
end
