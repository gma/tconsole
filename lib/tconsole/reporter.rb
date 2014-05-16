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
      puts ::Termin::ANSIColor.green(message)
    end

    # Public: Outputs a warning message.
    def warn(message = "")
      puts ::Termin::ANSIColor.yellow(message)
    end

    # Public: Outputs an error message.
    def error(message = "")
      puts ::Termin::ANSIColor.red(message)
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
        print ::Termin::ANSIColor.red, output, ::Termin::ANSIColor.reset
      else
        print ::Termin::ANSIColor.green, output, ::Termin::ANSIColor.reset
      end

      print ::Termin::ANSIColor.magenta, " #{last_result}", ::Termin::ANSIColor.reset, "\n"
    end

    # Public: Prints a list of available commands
    def help_message
      puts
      puts "Available commands:"
      puts
      puts "reload                      # Reload your Rails environment"
      puts "set [variable] [value]      # Sets a runtime variable (see below for details)"
      puts "exit                        # Exit the console"
      puts "!failed                     # Runs the last set of failing tests"
      puts "!timings [limit]            # Lists the timings for the last test run, sorted."
      puts "[filename] [test_pattern]   # Run the tests contained in the given file"
      puts ".[command]                  # Executes the given command in a subshell"
      puts
      puts "Running file sets"
      puts
      puts "File sets are sets of files that are typically run together. For example,"
      puts "in Rails projects it's common to run `rake test:units` to run all of the"
      puts "tests under the units directory."
      puts
      puts "Available file sets:"

      config.file_sets.each do |set, paths|
        puts set
      end

      puts
      puts "Working with test patterns:"
      puts
      puts "All of the test execution commands include an optional test_pattern argument. A"
      puts "test pattern can be given to filter the executed tests to only those tests whose"
      puts "name matches the pattern given. This is especially useful when rerunning a failing"
      puts "test."
      puts
      puts "Runtime Variables"
      puts
      puts "You can set runtime variables with the set command. This helps out with changing"
      puts "features that you may want to change at runtime. At present, the following"
      puts "runtime variables are available:"
      puts
      puts "fast        # Turns on fail fast mode. Values: on, off"
      puts

    end

    # Public: Outputs the tconsole welcome message
    def welcome_message
      info
      info("Welcome to #{config.app} (v#{TConsole::VERSION}). Type 'help' for help or 'exit' to quit.")
    end

    # Public: Outputs the tconsole exit message
    def exit_message
      info
      info("Exiting. Bye!")
    end
  end
end
