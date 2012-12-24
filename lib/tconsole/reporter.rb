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

    # Public: Outputs a positive informative message.
    # Colors it green if the console supports it.
    def exclaim(message = "")
      puts ::Term::ANSIColor.green(message)
    end

    # Public: Outputs a warning message.
    def warn(message = "")
      puts ::Term::ANSIColor.yellow(message)
    end

    # Public: Outputs an error message.
    def error(message = "")
      puts ::Term::ANSIColor.red(message)
    end


    # Public: Outputs a trace message, when needed.
    def trace(message = "")
      puts "[tconsole trace] #{message}" if config.trace?
    end

    # Public: Prints a backtrace out.
    def trace_backtrace(exception)
      trace("===========")
      trace(exception.backtrace.join("\n"))
      trace("===========")
    end

    # Public: Outputs a timing for the timings command, using the proper
    # color logic
    def timing(timing, test_id)
      output = "#{"%0.6f" % timing[:time]}s #{timing[:name]}"
      if timing[:time] > 1
        print ::Term::ANSIColor.red, output, ::Term::ANSIColor.reset
      else
        print ::Term::ANSIColor.green, output, ::Term::ANSIColor.reset
      end

      print ::Term::ANSIColor.magenta, " #{last_result}", ::Term::ANSIColor.reset, "\n"
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
