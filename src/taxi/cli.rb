# frozen_string_literal: true

require 'thor'
require 'taxi/config'
require 'taxi/connector/aws'
require 'taxi/connector/sftp'

require 'taxi/commands/package'
require 'taxi/commands/status'
require 'taxi/commands/review'

require 'taxi/utils/log'

module Taxi
  module SubCLI
    class PackageCommand < Thor
      class_option :bucket, default: ENV['AWS_DEFAULT_BUCKET'], desc: 'Specify a S3 bucket (default: ENV["AWS_DEFAULT_BUCKET"])'

      desc 'make <name> <path>', 'Create a translation package for <name> at <path> on S3'
      def make(name, path)
        Log.info("package make name=#{name} path=#{path} bucket=#{options[:bucket]}")

        unless options[:bucket]
          raise EngineFailure, '--bucket was not specified and $AWS_DEFAULT_BUCKET is not set'
        end
        ::Taxi::Package.make(name, path, bucket: options[:bucket])
      end

      desc 'translate name from to',
        'Upload the translation package with name and languages from and to
        (default: name=en_US)'
      option :agency, required: true
      def translate(name, from='en_US', to)
        agency = options[:agency]
        Log.info("package translate name=#{name} from=#{from} to=#{to} agency=#{agency}")
        ::Taxi::Package.translate(name, from: from, to: to, agency: agency)
      end

      desc 'deploy <name> <path> [<from>] <to>', 'Deploy translation package <name> (translated <from> to <to>) to S3.
      Will be uploaded under <path>/ru for ru_RU, <path>/it for it_IT, etc.
      ! <from> defaults to "en_US"'
      option :agency, required: true
      def deploy(name, path, from="en_US", to)
        agency = options[:agency]
        bucket = options[:bucket]
        Log.info("package deploy name=#{name} path=#{path} from=#{from} " \
          "to=#{to} agency=#{agency} bucket=#{bucket}")
        unless options[:bucket]
          raise EngineFailure, '--bucket was not specified and $AWS_DEFAULT_BUCKET is not set'
        end

        ::Taxi::Package.deploy(
          name, path, from: from, to: to, bucket: bucket, agency: agency
        )
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
      class_option :agency, required: true

      desc 'ls [path]', 'List files'
      def ls(path = '/')
        agency = options[:agency]
        ::Taxi::SFTP.new(agency).print_ls(path)
      end

      desc 'mv name [from] [to]', 'Move a package - name may include language codes (default: from OPEN to DEPLOY)'
      def mv(name, from = DirConfig::OPEN, to = DirConfig::DEPLOY)
        agency = options[:agency]
        ::Taxi::SFTP.new(agency).move_glob(name, from, to)
      end
    end

    class StatusCommand < Thor
      class_option :format, default: 'text'
      class_option :agency, required: false

      desc 'all', 'List packages by status'
      def all
        f = options[:format]
        a = options[:agency]
        ::Taxi::Status.list_all(format: f, agency: a)
      end

      desc 'open', 'List all untranslated packages'
      def open
        ::Taxi::Status.list_by_status(status: 'open', format: options[:format], agency: options[:agency])
      end

      desc 'deploy', 'List packages ready to deploy'
      def deploy
        ::Taxi::Status.list_by_status(status: 'deploy', format: options[:format], agency: options[:agency])
      end

      desc 'done', 'List translated packages'
      def done
        ::Taxi::Status.list_by_status(status: 'done', format: options[:format], agency: options[:agency])
      end
    end

    class ReviewCommand < Thor
      class_option :format, default: 'html'
      class_option :agency, required: true

      desc 'create <name> <lang_code> <from> [to=latest] [format=html]', 'Create file that shows changes between translations since <from>.'
      def create(name, lang, from, to = 'latest')
        ::Taxi::Review.create(
          name, lang, from, to, format: options[:format], agency: options[:agency]
        )
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

    desc 'review SUBCOMMAND ...ARGS', 'Review changes'
    subcommand 'review', SubCLI::ReviewCommand

    desc 'sftp SUBCOMMAND ...ARGS', 'SFTP operations'
    subcommand 'sftp', SubCLI::SFTPCommand

    desc 'status', 'Checks translation packages for reviews and outstanding deployments'
    subcommand 'status', SubCLI::StatusCommand

    desc 'config', 'Output the currently loaded config'
    def config
      unless ENV.key?('TAXI_ENV')
        raise StandardError, 'Tried to print environment without $TAXI_ENV set. ' \
          'Abort printing production credentials.'
      end

      Config.instance.print
    end
  end
end
