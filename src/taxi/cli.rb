# frozen_string_literal: true

require 'thor'
require 'taxi/config'
require 'taxi/connector/aws'
require 'taxi/connector/sftp'

require 'taxi/commands/package'
require 'taxi/commands/status'

require 'taxi/utils/log'


module Taxi
  module SubCLI
    class ReviewCommand < Thor
      desc 'inspect <name> <from> <to> ',
        'Download translated package (<name> translated to <to>) to review cache in order to inspect it
        <from> defaults to "en_US"'
      def inspect(name, from='en_US', to)
        Log.info("review inspect name=#{name} from=#{from} to=#{to}")
        ::Taxi::Package.review_inspect(name, from: from, to: to)
      end

      desc 'pass <name> <from> <to>',
        'Mark this package <name> (translated to <to>) as "review passed" and move it to the deploy stage
        <from> defaults to "en_US"'
      def pass(name, from='en_US', to)
        Log.info("review pass name=#{name} from=#{from} to=#{to}")
        ::Taxi::Package.review_pass(name, from: from, to: to)
      end
    end

    class PackageCommand < Thor
      desc 'make <name>', 'Create a translation package for <name>'
      def make(name)
        Log.info("package make name=#{name}")
        ::Taxi::Package.make(name)
      end

      desc 'translate <name> <from> <to>',
        'Upload the translation package <name> to SFTP to be translated to from language <from> to <to>
        <from> defaults to "en_US"'
      def translate(name, from='en_US', to)
        Log.info("package translate name=#{name} from=#{from} to=#{to}")
        ::Taxi::Package.translate(name, from: from, to: to)
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
      desc 'ls [path]', 'List files on the SFTP server'
      def ls(path = '/')
        ::Taxi::SFTP.instance.print_ls(path)
      end
    end

    class StatusCommand < Thor
      class_option :format, default: 'text'

      desc 'all', 'List packages by status'
      def all
        ::Taxi::Status.list_all(format: options[:format])
      end

      desc 'open', 'List all untranslated packages'
      def open
        ::Taxi::Status.list_by_status(status: 'open', format: options[:format])
      end

      desc 'review', 'List packaes in review'
      def review
        ::Taxi::Status.list_by_status(status: 'review', format: options[:format])
      end

      desc 'deploy', 'List packages ready to deploy'
      def deploy
        ::Taxi::Status.list_by_status(status: 'deploy', format: options[:format])
      end

      desc 'done', 'List translated packages'
      def done
        ::Taxi::Status.list_by_status(status: 'done', format: options[:format])
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

    desc 'review SUBCOMMAND ...ARGS', 'SFTP operations'
    subcommand 'review', SubCLI::ReviewCommand

    desc 'status', 'Checks translation packages for reviews and outstanding deployments'
    subcommand 'status', SubCLI::StatusCommand

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
