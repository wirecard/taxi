# frozen_string_literal: true
require 'taxi/config'

module Taxi
  class S3
    include Singleton

    def ls(bucket)
      puts "> AWS Bucket: ls #{bucket}".yellow
      response = @s3_client.list_objects_v2(bucket: bucket)
      files = response.contents
      files_str = files.map do |entry|
        "#{entry.last_modified.to_s.greenish}\t#{entry.size.to_s.blueish}\t#{entry.key.yellow}"
      end
      files_str.each do |entry|
        puts entry
      end
    end

    def list_buckets
      puts '> AWS Buckets'.yellow
      response = @s3_client.list_buckets
      buckets = response.buckets.map do |bucket|
        "#{bucket.name.yellow} - created: #{bucket.creation_date.to_s.greenish}"
      end
      buckets.each do |bucket|
        puts bucket
      end
    end

    private

    def initialize
      @s3_client = Config.instance.aws_s3_client
    end
  end
end
