# frozen_string_literal: true

require 'tmpdir'
require 'zlib'
require 'fileutils'
require 'date'
require 'progressbar'

require 'taxi/config'
require 'taxi/utils/log'

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

    def download(bucket, site, dir)
      puts "> AWS Download: #{site} @ #{bucket}".yellow
      s3 = s3_client

      # get list of objects
      response = s3.list_objects_v2(bucket: bucket, prefix: site)
      files = response.contents.map(&:key).reject do |path|
        [
          '*/branches/**', '*/tags/**', '*/pr/**', # exclude git subfolders
          '*/tmp/**', '*/trash/**', # exclude user subfolders
          '*/??/**' # exclude language subfolders, e.g. ru/ or de/
        ].any? { |glob| File.fnmatch(glob, path) }
      end

      if files.size.zero?
        raise AWSError.new("No files downloaded: #{bucket} @ #{site}")
      end

      # get tmp dir to save data to
      Log.debug("S3 download to  #{dir}")
      puts '> S3 Download'.green

      progress = ProgressBar.create(title: '  AWS::Get'.green, total: files.size)
      Dir.chdir(dir) do
        files.each do |file|
          # progress.title = file
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

    def upload(bucket, local_dir, remote_subdir=nil)
      puts "> AWS Upload: #{bucket}".yellow
      puts "              SUBDIR: #{remote_subdir}".yellow unless remote_subdir.nil?
      puts "              SOURCE: #{local_dir}".yellow
      raise FileNotFound.new(local_dir) unless File.exists?(local_dir)

      s3 = Aws::S3::Resource.new(client: s3_client)
      bucket = s3.bucket(bucket)

      files = Dir.glob(File.join(local_dir, '**/*')).reject { |f| File.directory?(f) }
      puts "> Uploading #{files.size} files".yellow
      progressbar = ProgressBar.create(title: '  AWS::Put'.yellow, total: files.size)
      files.each do |file|
        basename = File.basename(file)
        file_path = (remote_subdir.nil?) ? basename : File.join(remote_subdir, basename)
        bucket.object(file_path).upload_file(file) do |response|
          progressbar.increment
        end
        # s3.put_object(
        #   body: file,
        #   bucket: bucket,
        #   key: File.join(remote_subdir, File.basename(file))
        # )
      end
      progressbar.finish unless progressbar.finished?
    end

    def delete(bucket, dir)
      puts "> AWS Delete: #{bucket}".yellow
      puts "              DIR: #{dir}".yellow

      s3 = Aws::S3::Resource.new(client: s3_client)
      bucket = s3.bucket(bucket)
      bucket.object(dir).delete
    end

    def file_exists?(bucket, file)
      s3 = Aws::S3::Resource.new(client: s3_client)
      bucket = s3.bucket(bucket)
      puts "> AWS Check: '#{file}' exists?".yellow
      bucket.object(file).exists?
    end

    def dir_exists?(bucket, dir)
      s3 = Aws::S3::Resource.new(client: s3_client)
      bucket = s3.bucket(bucket)
      puts "> AWS Check: '#{dir}' exists?".yellow
      bucket.objects({ prefix: dir }).limit(1).any?
    end

    private

    def s3_client
      role_credentials = aws_assume_role
      s3 = Aws::S3::Client.new(
        credentials: role_credentials,
        force_path_style: true,
        http_proxy: ENV['TAXI_HTTP_PROXY']
      )
      s3
    end

    def aws_assume_role
      aws_config = Config.instance.aws_config
      tags = ['client TAXI', 'repository wirecard/taxi', 'team tecdoc']
      tags.map! do |entry|
        key, value = entry.split(' ')
        { key: key, value: value }
      end

      Aws::AssumeRoleCredentials.new(
        client: @aws_sts_client,
        role_arn: aws_config.role_assume,
        role_session_name: 'TecDoc-Taxi',
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
