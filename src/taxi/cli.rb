# frozen_string_literal: true

require 'thor'

module Taxi
  module SubCLI
    class Package < Thor
      desc 'make <url>', 'Create a translation package for URL'
      def make(name)
        puts "make #{url}"
      end

      desc 'translate <id> <target-language>', 'Upload the translation package name ID to SFTP'
      def translate(id, language)
        puts "translate #{id} #{language}"
      end

      desc 'deploy <id> <language>', 'Deploy translation package named ID to S3'
      option :remove, type: :boolean
      def deploy(id, language)
        puts "deploy #{id} #{language}"
      end
    end
  end

  class CLI < Thor
    option :debug, type: :boolean

    desc 'package SUBCOMMAND ...ARGS', 'Package operations'
    long_desc <<-LONGDESC
The package subcommand provides an interface to create, upload and deploy translation packages.
    LONGDESC
    subcommand 'package', SubCLI::Package

    desc 'status', 'Checks translation packages for reviews and outstanding deployments'
    option :package, type: :string
    def status
      puts 'status'
    end

  end
end
