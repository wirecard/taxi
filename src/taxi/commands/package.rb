# frozen_string_literal: true
require 'taxi/config'
require 'taxi/connector/aws'
require 'taxi/utils/compression'
require 'taxi/utils/package'

module Taxi
  module Package
    def self.make(bucket)
      Dir.mktmpdir do |dir|
        ::Taxi::S3.download(bucket, dir)

        filepath = File.join(
          Config.cache_dir,
          "#{Utils.dated_package_name(bucket)}.tar.gz"
        )
        targzfile = Compression.targz(dir)

        File.write(filepath, targzfile)
        puts "> Package written: #{filepath.whiteish}".green
      end
    end

    def self.translate(name, language_code)
      puts Utils.folder_structure(name, to: language_code)
      raise NotImplementedError.new('package translate')

      # deprecated
      # filename = generate_filename(name, language_code)
      # local_filepath = File.join(Config.cache_dir, filename)
      # dest = remote_dirname(name, language_code)
      # ::Taxi::SFTP.file_upload(local_filepath, dest)
    end

  end
end
