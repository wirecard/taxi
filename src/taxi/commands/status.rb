# frozen_string_literal: true

require 'taxi/config'
require 'date'

module Taxi
  # Represents the status of translation packages
  class Status
    STATUS_FOLDERS = {
      'open' => DirConfig::OPEN,
      'deploy' => DirConfig::DEPLOY,
      'done' => DirConfig::DONE
    }.freeze
    LS_REGEX = /^(?<type>[d|-])r[rwx-]{8} .+ (?<mod_month>\w+) (?<mod_day>[0-9]{2}) ((?<mod_hour>[0-9]{2}):(?<mod_minute>[0-9]{2})|(?<mod_year>[0-9]{4})) (?<name>[\w]+)$/.freeze

    # List all entries for a given agency in the specified format.
    #
    # @param format [String] 'json' or 'text' (defaults to 'text' for all other values)
    # @param agency [String] agency on the SFTP, i.e. SFTP user
    # @return [nil]
    def self.list_all(format:, agency:)
      # TODO: this is so fugly, please rewrite
      # check if specified agency is a valid agency
      # yes? convert to array
      agencies_array = Config.agencies.to_h.keys.map { |k| k.to_s }

      if agency && !agencies_array.include?(agency)
        puts 'Valid agencies: ' + agencies_array.join(', ')
        return false
      else
        agencies = agency.split if agency
      end
      # if no agency was specified, use all
      agencies ||= agencies_array

      # list all translation agencies folders unless one is specified
      agencies.each do |a|
        puts "\n"
        puts Config.agencies[a][:name].green
        folders = ls_to_h(agency: a).select do |entry|
          (entry['type'] == 'd') && (STATUS_FOLDERS.include? entry['name'][2..-1])
        end
        folder_hash = {}
        folders.each do |folder|
          title = folder['name'][2..-1].upcase
          path = folder['name']
          folder_hash[title] = ls_to_h(path, agency: a)
        end
        print_folders(folder_hash: folder_hash, format: format)
      end
    end

    # Print the folder structure in the given format.
    #
    # @param folder_hash [Hash{String => String, Hash}] Hash of Strings
    # that represents the folder structure recursively
    # @param format [String] 'json' or 'text' (defaults to 'text' for all other values)
    #
    def self.print_folders(folder_hash:, format:)
      time_format = '%A, %B %d %Y, %H:%M W%V'
      output_hash = {}
      folder_hash.each do |k, entries|
        puts k.yellow unless format == 'json'
        output_hash[k] = []
        entries.each do |entry|
          date_string = Time.at(entry['attributes'].mtime).strftime(time_format)
          unless format == 'json'
            str_length = 78 - entry['name'].length
            puts "#{entry['name']} #{date_string.rjust(str_length, '.')}"
          end
          output_hash[k] << {
            name: entry['name'],
            timestamp: entry['attributes'].mtime
          }
        end
      end
      return unless format == 'json'

      puts JSON.pretty_unparse(output_hash) if format == 'json'
    end

    # Return a hash describing the folder structure at +path+ for user +agency+.
    #
    # @param path [String] path for ls (default: '/')
    # @param agency [String] agency on the SFTP, i.e. SFTP user
    def self.ls_to_h(path = '/', agency:)
      if @agency != agency
        @sftp = ::Taxi::SFTP.new(agency)
        @agency = agency
      else
        @sftp ||= ::Taxi::SFTP.new(agency)
      end
      entries = @sftp.ls(path)
      entries = entries.select do |e|
        true unless e.name =~ /^\.+/
      end
      entries = entries.map do |e|
        {
          'name' => e.name,
          'type' => e.longname[0] == 'd' ? 'd' : 'f',
          'attributes' => e.attributes
        }
      end

      entries = entries.sort_by do |entry|
        entry['name']
      end
      entries
    end

    def self.list_by_language(lang:); end

    def self.list_by_name(name:); end

    # Only list packages with a certain status.
    #
    # @param [Hash{Symbol => String}] must contain the keys
    # :status, :format and :agency
    # @return [nil]
    #
    def self.list_by_status(**kwargs)
      status = kwargs[:status]
      format = kwargs[:format]
      agency = kwargs[:agency]
      return unless STATUS_FOLDERS[status]

      title = status.upcase
      path = STATUS_FOLDERS[status]
      folder_hash = {}
      folder_hash[title] = ls_to_h(path, agency: agency)
      print_folders(folder_hash: folder_hash, format: format)
    end

    def self.list_by_last_x_days(days:); end

    # OBSOLETE
    def self.parse_raw_date(line)
      # handle folders which have a different year
      year = line[LS_REGEX, :mod_year] || DateTime.now.year
      month = line[LS_REGEX, :mod_month]
      day = line[LS_REGEX, :mod_day]
      hour = line[LS_REGEX, :mod_hour]
      minute = line[LS_REGEX, :mod_minute]
      # TODO: server time zone?
      DateTime.parse("#{year}#{month}#{day}T#{hour}#{minute}00+01")
    end
  end
end
