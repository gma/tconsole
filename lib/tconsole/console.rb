module TConsole
  class Console
    KNOWN_COMMANDS = ["exit", "reload", "help", "info", "!failed", "!timings", "set"]

    def initialize(config)
      @config = config
      read_history

      define_autocomplete
    end

    def define_autocomplete
      Readline.completion_append_character = ""

      # Proc for helping us figure out autocompletes
      Readline.completion_proc = Proc.new do |str|
        known_commands = KNOWN_COMMANDS.grep(/^#{Regexp.escape(str)}/)

        files = Dir[str+'*'].grep(/^#{Regexp.escape(str)}/)
        formatted_files = files.collect do |filename|
          if File.directory?(filename)
            filename + File::SEPARATOR
          else
            filename
          end
        end

        known_commands.concat(formatted_files).concat(@config.file_sets.keys)
      end
    end

    # Returns true if the app should keep running, false otherwise
    def read_and_execute(server)
      while line = Readline.readline("tconsole> ", false)
        line.strip!
        args = Shellwords.shellwords(line)

        # save the line unless we're exiting or repeating the last command
        unless args[0] == "exit" || Readline::HISTORY[Readline::HISTORY.length - 1] == line
          Readline::HISTORY << line
        end

        if line == ""
          # do nothing
        elsif args[0] == "exit"
          return false
        elsif args[0] == "reload"
          return true
        elsif args[0] == "help"
          print_help
        elsif args[0] == "!failed"
          server.run_failed
        elsif args[0] == "!timings"
          server.show_performance(args[1])
        elsif args[0] == "info"
          server.run_info
        elsif args[0] == "set"
          server.set(args[1], args[2])
        elsif @config.file_sets.has_key?(args[0])
          server.run_file_set(args[0])
        else
          puts args[0]
          server.run_tests([args[0]], args[1])
        end
      end

      true
    end

    # Prints a list of available commands
    def print_help
      puts
      puts "Available commands:"
      puts
      puts "reload                      # Reload your Rails environment"
      puts "set [variable] [value]      # Sets a runtime variable (see below for details)"
      puts "exit                        # Exit the console"
      puts "!failed                     # Runs the last set of failing tests"
      puts "!timings [limit]            # Lists the timings for the last test run, sorted."
      puts "[filename] [test_pattern]   # Run the tests contained in the given file"
      puts
      puts "Running file sets"
      puts
      puts "File sets are sets of files that are typically run together. For example,"
      puts "in Rails projects it's common to run `rake test:units` to run all of the"
      puts "tests under the units directory."
      puts
      puts "Available file sets:"

      @config.file_sets.each do |set, paths|
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
      puts "features of TConsole that you may want to change at runtime. At present, the"
      puts "following runtime variables are available:"
      puts
      puts "fast        # Turns on fail fast mode. Values: on, off"
      puts

    end

    def history_file
      File.join(ENV['HOME'], ".tconsole_history")
    end

    # Stores last 50 items in history to $HOME/.tconsole_history
    def store_history
      if ENV['HOME']
        File.open(history_file, "w") do |f|
          Readline::HISTORY.to_a.reverse[0..49].each do |item|
            f.puts(item)
          end
        end
      end
    end

    # Loads history from past sessions
    def read_history
      if ENV['HOME'] && File.exist?(history_file)
        File.readlines(history_file).reverse.each do |line|
          Readline::HISTORY << line
        end
      end
    end
  end
end
