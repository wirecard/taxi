# frozen_string_literal: true

require 'taxi/config'
require 'date'

module Taxi
  module Status
    STATUS_FOLDERS = {
      'open' => DirConfig::OPEN,
      'deploy' => DirConfig::DEPLOY,
      'done' => DirConfig::DONE
    }.freeze
    LS_REGEX = /^(?<type>[d|-])r[rwx-]{8} .+ (?<mod_month>\w+) (?<mod_day>[0-9]{2}) ((?<mod_hour>[0-9]{2}):(?<mod_minute>[0-9]{2})|(?<mod_year>[0-9]{4})) (?<name>[\w]+)$/.freeze

    def self.list_all(format:, agency:)
      folders = ls_to_h(agency: agency).select do |entry|
        (entry['type'] == 'd') && (STATUS_FOLDERS.include? entry['name'][2..-1])
      end
      folder_hash = {}
      folders.each do |folder|
        title = folder['name'][2..-1].upcase
        path = File.join('/', folder['name'])
        folder_hash[title] = ls_to_h(path, agency: agency)
      end
      print_folders(folder_hash: folder_hash, format: format)
    end

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

    def self.ls_to_h(path = '/', agency:)
      sftp = ::Taxi::SFTP.new(agency)
      entries = sftp.ls(path)
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

    def self.list_by_status(**kwargs)
      status = kwargs[:status]
      format = kwargs[:format]
      agency = kwargs[:agency]
      return unless STATUS_FOLDERS[status]

      title = status.upcase
      path = File.join('/', STATUS_FOLDERS[status])
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
