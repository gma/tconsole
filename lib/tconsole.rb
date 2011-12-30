require "tconsole/version"
require "tconsole/server"

require "readline"
require "benchmark"
require "drb/drb"

module TConsole
  class Runner

    SERVER_URI = "druby://localhost:8788" 
    # Spawns a new environment. Looks at the results of the environment to determine whether to stop or
    # keep running
    def self.run
      stty_save = `stty -g`.chomp

      running = true
      trap("SIGINT", "SYSTEM_DEFAULT")

      # A little welcome
      puts
      puts "Welcome to tconsole. Type 'help' for help or 'exit' to quit."

      # Set up our console input handling and history
      console = Console.new

      # Start the server
      while running
        # ignore ctrl-c during load, since things can get kind of messy if we don't

        fork do
          begin
            server = Server.new

            DRb.start_service(SERVER_URI, server)

            DRb.thread.join
          rescue Interrupt
            # do nothing here since the outer process will shut things down for us
          end
        end

        # Set up our client connection to the server
        server = DRbObject.new_with_uri(SERVER_URI)

        loaded = false
        wait_until = Time.now + 10
        until loaded || Time.now > wait_until
          begin
            running = server.load_environment
            loaded = true
          rescue
            loaded = false
          rescue Interrupt
            # do nothing if we get an interrupt
            puts "Interrupted in client"
          end
        end

        if !loaded
          puts
          puts "Couldn't connect to test environment. Exiting."
          exit(1)
        end

        running = console.read_and_execute(server) if running

        server.stop
        Process.waitall
      end

      console.store_history

      puts
      puts "Exiting. Bye!"
      system("stty", stty_save);
    end
  end

  class Console

    def initialize
      read_history
    end

    # Returns true if the app should keep running, false otherwise
    def read_and_execute(server)
      while line = Readline.readline("tconsole> ", true)
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
        elsif args[0] == "units"
          server.run_tests(["test/unit/**/*_test.rb"], args[1])
        elsif args[0] == "functionals"
          server.run_tests(["test/functional/**/*_test.rb"], args[1])
        elsif args[0] == "integration"
          server.run_tests(["test/integration/**/*_test.rb"], args[1])
        elsif args[0] == "recent"
          server.run_recent(args[1])
        elsif args[0] == "uncommitted"
          server.run_uncommitted(args[1])
        elsif args[0] == "all"
          server.run_tests(["test/unit/**/*_test.rb", "test/functional/**/*_test.rb", "test/integration/**/*_test.rb"], args[1])
        elsif args[0] == "info"
          server.run_info
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
      puts "all [test_pattern]          # Run all test types (units, functionals, integration)"
      puts "units [test_pattern]        # Run unit tests"
      puts "functionals [test_pattern]  # Run functional tests"
      puts "integration [test_pattern]  # Run integration tests"
      puts "recent [test_pattern]       # Run tests for recently changed files"
      puts "uncommitted [test_pattern]  # Run tests for uncommitted changes"
      puts "[filename] [test_pattern]   # Run the tests contained in the given file"
      puts "reload                      # Reload your Rails environment"
      puts "exit                        # Exit the console"
      puts
      puts
      puts "Working with test patterns:"
      puts
      puts "All of the test execution commands include an optional test_pattern argument. A"
      puts "test pattern can be given to filter the executed tests to only those tests whose"
      puts "name matches the pattern given. This is especially useful when rerunning a failing"
      puts "test."
      puts
    end

    def history_file
      File.join(ENV['HOME'], ".tconsole_history")
    end

    # Stores last 50 items in history to $HOME/.tconsole_history
    def store_history
      if ENV['HOME']
        File.open(history_file, "w") do |f|
          Readline::HISTORY.to_a[0..49].each do |item|
            f.puts(item)
          end
        end
      end
    end

    # Loads history from past sessions
    def read_history
      if ENV['HOME'] && File.exist?(history_file)
        File.readlines(history_file).each do |line|
          Readline::HISTORY.push(line)
        end
      end
    end
  end
end
