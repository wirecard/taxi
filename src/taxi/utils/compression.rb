# frozen_string_literal: true

require 'zlib'
require 'minitar'

module Taxi
  module Compression
    def self.targz(path, targz_file)
      Minitar.pack(path, Zlib::GzipWriter.new(File.open(targz_file, 'wb')))
    end

    def self.untargz(targz_file, dst_dir)
      Minitar.unpack(Zlib::GzipReader.new(File.open(targz_file, 'rb')), dst_dir)
    end
  end
end
