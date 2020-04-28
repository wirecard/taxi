# frozen_string_literal: true

module Taxi
  module Translate
    def self.translate(name, language_code)
      filename = generate_filename(name, language_code)
      local_filepath = File.join(Config.cache_dir, filename)
      dest = remote_dirname(name, language_code)
      ::Taxi::SFTP.file_upload(local_filepath, dest)
    end

    def time_string(name)
      today = Date.today.strftime('%Y%m%d')
      "#{name}-#{today}.tar.gz"
    end

    def remote_dirname(name, language_code)
      return name
    end
  end
end
