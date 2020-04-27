# frozen_string_literal: true

require 'tmpdir'
require 'zlib'
require 'fileutils'
require 'date'
require 'progressbar'

require 'taxi/config'

module Taxi
  class S3
    include Singleton

    # forward missing static method to instance
    def self.method_missing(method_name, *arguments)
      instance.send(method_name, *arguments)
    end

    def list_buckets
      puts '> AWS Buckets'.yellow
      response = s3_client.list_buckets
      buckets = response.buckets.map do |bucket|
        "#{bucket.name.yellow} - created: #{bucket.creation_date.to_s.greenish}"
      end
      buckets.each do |bucket|
        puts bucket
      end
    end

    def ls(bucket)
      puts "> AWS Bucket: ls #{bucket}".yellow
      response = s3_client.list_objects_v2(bucket: bucket)
      files = response.contents
      files_str = files.map do |entry|
        "#{entry.last_modified.to_s.greenish}\t#{entry.size.to_s.blueish}\t#{entry.key.yellow}"
      end
      files_str.each do |entry|
        puts entry
      end
    end

    def download(bucket, dir)
      puts "> AWS Bucket: get #{bucket}".yellow
      s3 = s3_client

      # get list of objects
      response = s3.list_objects_v2(bucket: bucket)
      files = response.contents.map(&:key)
      # get tmp dir to save data to
      puts "> Starting download to #{dir.white}".green

      progress = ProgressBar.create(title: 'AWS::Get'.green, total: files.size)
      Dir.chdir(dir) do
        files.each do |file|
          FileUtils.mkdir_p(File.dirname(file))
          s3.get_object(
            response_target: file,
            bucket: bucket,
            key: file
          )
          progress.increment
        end
      end
      progress.finish unless progress.finished?
    end

    private

    def s3_client
      role_credentials = aws_assume_role
      s3 = Aws::S3::Client.new(
        credentials: role_credentials,
        force_path_style: true,
        http_proxy: ENV['AWS_HTTP_PROXY']
      )
      s3
    end

    def aws_assume_role
      aws_config = Config.instance.aws_config
      tags = ['client TAXI', 'repository wirecard/taxi', 'team tecodc']
      tags.map! do |entry|
        key, value = entry.split(' ')
        { key: key, value: value }
      end

      Aws::AssumeRoleCredentials.new(
        client: @aws_sts_client,
        role_arn: aws_config.role_assume,
        role_session_name: 'github://wirecard/taxi',
        duration_seconds: 1200,
        tags: tags
      )
    end

    def initialize
      Config.instance
      @aws_sts_client = Aws::STS::Client.new
    end
  end
end
