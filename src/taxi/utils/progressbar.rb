# frozen_string_literal: true

require 'progressbar'

module Taxi::Utils
  class ProgressBarHandler
    def initialize(title, total)
      @progressbar = ProgressBar.create(title: title, total: total)
    end

    def on_open(downloader, file)
      @progressbar.increment
    end

    def on_get(downloader, file, offset, data)
    end

    def on_close(downloader, file)
    end

    def on_mkdir(downloader, path)
      @progressbar.increment
    end

    def on_finish(downloader)
      @progressbar.finish unless @progressbar.finished?
    end

  end
end
