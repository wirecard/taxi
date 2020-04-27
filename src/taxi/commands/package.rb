# frozen_string_literal: true
require 'taxi/connector/aws'

module Taxi
  module Package
    def self.make(bucket)
      ::Taxi::S3.get(bucket)
    end
  end
end
