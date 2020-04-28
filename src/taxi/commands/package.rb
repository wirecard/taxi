# frozen_string_literal: true
require 'taxi/config'
require 'taxi/connector/aws'
require 'taxi/utils/compression'

module Taxi
  module Package
    def self.make(bucket)
      Dir.mktmpdir do |dir|
        ::Taxi::S3.download(bucket, dir)
        filepath = File.join(Config.cache_dir, "#{bucket}.tar.gz")
        targzfile = Compression.targz(dir)

        File.write(filepath, targzfile)
        puts "> Package written: #{filepath.whiteish}".green
      end
    end
  end
end
