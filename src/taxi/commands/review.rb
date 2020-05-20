# frozen_string_literal: true

require 'fast_html_diff'
require 'nokogiri'

module Taxi
  module Review
    ## Assumes source language is always en_US
    # - 3_done/
    # --- CAPS_2020_04_22_1830
    # ----- en_US
    # ------- *.html
    # ----- fr_FR
    # ------- *.html

    # for debugging:
    # bundle exec ./bin/taxi review CAPS fr_FR 2020-04-22-1xxx
    # bundle exec ./bin/taxi review CAPS fr_FR 2020-04-22-1830

    def self.create(name, lang, from, to)
      # make sure package for given lang and from date exists
      generate_report(name, lang, from, to)
    end

    def self.latest_of(name, lang)
      path = File.join('share', '3_done').to_s

      # get all translations and look for latest
      package_name = ::Taxi::Status.ls_to_h(path).select { |t| t['name'].start_with?(name) }.last['name']
      m = package_name.match(/.*(<?date>[0-9_-]+)$/)
      return m[:date]

    end

    def self.generate_report(name, lang, from, to)

      pp name
      pp lang

      pp from



      to = latest_of(name, lang) if to == 'latest'

      pp to

      exit

      
      # make sure package for given to date exists as well
      path_to = translation_path(name: name, lang: lang, date_string: to)

      pp path_to

      exit


      # if file is removed, compare with empty string
      path_from = translation_path(name: name, lang: 'en_US', date_string: from)
      return false unless path_from

      puts "yep, translation to #{lang} exists for #{name} and date #{from}"
      return false unless path_to
      
      puts 'paths'.yellow
      pp path_from
      pp path_to

      exit

      files_origin = ::Taxi::Status.ls_to_h(path_from).select { |t| t['name'].end_with?('.html') }
      files_translated = ::Taxi::Status.ls_to_h(path_to).select { |t| t['name'].end_with?('.html') }

      pp files_origin
      pp files_translated

      # merge arrays
    end

    def self.translation_path(name:, lang:, date_string:)
      date_string = date_string.gsub(/-/, '_')

      # base_path is path of e.g. CAPS that contains lang dirs
      # e.g. base_path = /share/3_done/CAPS-2020-04-22-1830
      folder_name = name + '_' + date_string
      base_path = File.join('share', '3_done', folder_name).to_s
      path = File.join(base_path, lang).to_s
      return path if ::Taxi::SFTP.exists? path

      puts "Warning: Translation #{folder_name} not found!"
      puts "Available Translations:\n"
      ::Taxi::Status.ls_to_h('/share/3_done').each do |entry|
        puts entry['name'] + ':'
        p = File.join('/share', '3_done', entry['name']).to_s
        ::Taxi::Status.ls_to_h(p).each do |e|
          puts " - #{e['name']}" unless e['name'] == 'en_US'
        end
      end

      # # TODO: path not hardcoded

      # # get all translations
      # all_translations = ::Taxi::Status.ls_to_h('/share/3_done').map  do |entry|
      #   next unless entry['name']

      #   entry['name'].gsub(/_/,'-').downcase
      # end

      # # Show only translations that match given name and date
      # # e.g. caps-2020-04-13
      # dir_string = name + '-' + date_string
      # unless all_translations.include? dir_string
      #   puts "no matching translations found for #{dir_string}"
      #   puts 'available:'
      #   pp all_translations
      #   return nil
      # end

      # Further check if there is a translation to the requested lang available

      # if matches .lentth > 1, print all matches and "warning ambiguoous"
    end
    # def self.list_by_status(**kwargs)
    #   status = kwargs[:status]
    #   format = kwargs[:format]
    #   return unless STATUS_FOLDERS[status]

    #   title = status.upcase
    #   path = '/share/' + STATUS_FOLDERS[status]
    #   folder_hash = {}
    #   folder_hash[title] = ls_to_h(path)
    #   print_folders(folder_hash: folder_hash, format: format)
    # end
  end
end
