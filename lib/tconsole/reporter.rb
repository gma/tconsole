# Manages all output for TConsole
module TConsole
  class Reporter
    attr_accessor :config

    def initialize(config)
      self.config = config
    end

    # Public: Ouptuts an informative message.
    def info(message = "")
      puts message
    end

    # Public: Outputs an error message.
    def error(message = "")
      puts message
    end

    # Public: Outputs a trace message, when needed.
    def trace(message = "")
      puts "[tconsole trace] #{message}" if config.trace?
    end

    # Public: Prints a backtrace out.
    def trace_backtrace(exception)
      reporter.trace("===========")
      reporter.trace(exception.backtrace.join("\n"))
      reporter.trace("===========")
    end

    # Public: Outputs the tconsole welcome message
    def welcome_message
      info
      info("Welcome to tconsole (v#{TConsole::VERSION}). Type 'help' for help or 'exit' to quit.")
    end

    # Public: Outputs the tconsole exit message
    def exit_message
      info
      info("Exiting. Bye!")
    end
  end
end
