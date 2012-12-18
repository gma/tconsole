# Manages all output for TConsole
module TConsole
  class Reporter
    attr_accessor :config

    def initialize(config)
      self.config = config
    end

    def trace
      puts "[tconsole trace] #{message}" if config.trace?
    end
  end
end
