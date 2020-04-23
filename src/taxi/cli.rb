# frozen_string_literal: true

require 'thor'
require 'taxi/config'

module Taxi
  module SubCLI
    class Package < Thor
      desc 'make <name> <s3>', 'Create a translation package for <s3> named <name>'
      def make(name, s3)
        puts "make #{name} #{s3}"
      end

      desc 'translate <name> <language>', 'Upload the translation package <name> to SFTP to be translated to <language>'
      def translate(name, language)
        puts "translate #{name} #{language}"
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

    desc 'check-bucket <s3>', 'Checks the provided bucket <s3> and lists the files'
    def check_bucket(s3_id)
      puts "check_bucket #{s3_id}"
    end

    desc 'list-config', 'Output the currently loaded config'
    def list_config
      raise StandardError.new(
        'Tried to print environment without $DEV_ENV set. ' \
          'Abort printing production credentials.'
      ) if !ENV.key?('DEV_ENV')

      Config.instance.print
    end
  end
end
