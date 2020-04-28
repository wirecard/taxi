# frozen_string_literal: true

require 'thor'
require 'taxi/config'
require 'taxi/connector/aws'

require 'taxi/commands/package'
require 'taxi/commands/status'

require 'taxi/connector/sftp'


module Taxi
  module SubCLI
    class PackageCommand < Thor
      desc 'make <name>', 'Create a translation package for <s3> named <name>'
      def make(name)
        ::Taxi::Package.make(name)
      end

      desc 'translate <name> <from> <to>', 'Upload the translation package <name> to SFTP to be translated to from language <from> to <to>'
      def translate(name, language)
        puts "translate #{name} #{language}"
      end

      desc 'deploy <id> <language>', 'Deploy translation package named ID to S3'
      option :remove, type: :boolean
      def deploy(id, language)
        puts "deploy #{id} #{language}"
      end
    end

    class BucketCommand < Thor
      desc 'ls <bucket>', 'List files on the provided bucket <bucket>'
      def ls(bucket)
        ::Taxi::S3.instance.ls(bucket)
      end

      desc 'list', 'List buckets'
      def list
        ::Taxi::S3.instance.list_buckets
      end
    end

    class SFTPCommand < Thor
      desc 'ls', 'List files on the SFTP server'
      def ls
        ::Taxi::SFTP.instance.ls
      end
    end
  end

  class CLI < Thor
    option :debug, type: :boolean

    desc 'package SUBCOMMAND ...ARGS', 'Package operations'
    long_desc <<~LONGDESC
      The package subcommand provides an interface to create, upload and deploy translation packages.
    LONGDESC
    subcommand 'package', SubCLI::PackageCommand

    desc 'bucket SUBCOMMAND ...ARGS', 'Bucket operations'
    subcommand 'bucket', SubCLI::BucketCommand

    desc 'sftp SUBCOMMAND ...ARGS', 'SFTP operations'
    subcommand 'sftp', SubCLI::SFTPCommand

    desc 'status', 'Checks translation packages for reviews and outstanding deployments'
    option :package, type: :string
    def status
      puts 'status'
    end

    desc 'config', 'Output the currently loaded config'
    def config
      raise StandardError.new(
        'Tried to print environment without $DEV_ENV set. ' \
          'Abort printing production credentials.'
      ) if !ENV.key?('DEV_ENV')

      Config.instance.print
    end
  end
end
