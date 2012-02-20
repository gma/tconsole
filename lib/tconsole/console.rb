module TConsole
  class Console
    KNOWN_COMMANDS = ["exit", "reload", "help", "units", "functionals", "integration", "recent", "uncommitted", "all", "info", "!failed", "!timings", "set"]

    def initialize(config)
      @config = config
      read_history
    end

    # Returns true if the app should keep running, false otherwise
    def read_and_execute(server)
      while line = Readline.readline("tconsole> ", false)
        # TODO: Avoid pushing duplicate commands onto the history
        Readline::HISTORY << line

        line.strip!
        args = line.split(/\s/)

        if line == ""
          # do nothing
        elsif args[0] == "exit"
          return false
        elsif args[0] == "reload"
          return true
        elsif args[0] == "help"
          print_help
        elsif args[0] == "units" || args[0] == "unit"
          server.run_tests(["test/unit/**/*_test.rb"], args[1])
        elsif args[0] == "functionals" || args[0] == "functional"
          server.run_tests(["test/functional/**/*_test.rb"], args[1])
        elsif args[0] == "integration"
          server.run_tests(["test/integration/**/*_test.rb"], args[1])
        elsif args[0] == "recent"
          server.run_recent(args[1])
        elsif args[0] == "uncommitted"
          server.run_uncommitted(args[1])
        elsif args[0] == "all"
          server.run_tests(["test/unit/**/*_test.rb", "test/functional/**/*_test.rb", "test/integration/**/*_test.rb"], args[1])
        elsif args[0] == "!failed"
          server.run_failed
        elsif args[0] == "!timings"
          server.show_performance(args[1])
        elsif args[0] == "info"
          server.run_info
        elsif args[0] == "set"
          server.set(args[1], args[2])
        else
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
      puts "recent [test_pattern]       # Run tests for recently changed files"
      puts "uncommitted [test_pattern]  # Run tests for uncommitted changes"
      puts "!failed                     # Runs the last set of failing tests"
      puts "!timings [limit]            # Lists the timings for the last test run, sorted."
      puts "[filename] [test_pattern]   # Run the tests contained in the given file"
      puts "reload                      # Reload your Rails environment"
      puts "set [variable] [value]      # Sets a runtime variable (see below for details)"
      puts "exit                        # Exit the console"
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
