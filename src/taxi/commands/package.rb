# frozen_string_literal: true
require 'taxi/config'
require 'taxi/connector/aws'
require 'taxi/utils/compression'

module Taxi
  module Package
    def self.make(bucket)
      Dir.mktmpdir do |dir|
        ::Taxi::S3.download(bucket, dir)
        today = Date.today.strftime("%Y%m%d")
        filename = "#{bucket}-#{today}.tar.gz"
        filepath = File.join(Config.cache_dir, filename)

        # tarfile = ::Taxi::Utils::Tar.tar(dir)
        # targzfile = ::Taxi::Utils::Tar.gzip(tarfile)
        targzfile = Compression::targz(dir)

        File.open(filepath, 'w+') { |file| file.puts(targzfile) }
        puts "> Package written: #{filepath.whiteish}".green
      end
    end
  end
end
