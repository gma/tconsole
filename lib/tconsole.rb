require "tconsole/version"
require "tconsole/minitest"
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

        running = command_loop(server) if running

        server.stop
        Process.waitall
      end

      puts
      puts "Exiting. Bye!"
      system("stty", stty_save);
    end

    def self.command_loop(server)
      while line = Readline.readline("tconsole> ", true)
        if line == ""
          # do nothing
        elsif line == "exit"
          return false
        elsif line == "reload"
          return true
        elsif line == "help"
          help
        elsif line == "units"
          server.run_tests(["test/unit/**/*_test.rb"])
        elsif line == "functionals"
          server.run_tests(["test/functional/**/*_test.rb"])
        elsif line == "integration"
          server.run_tests(["test/integration/**/*_test.rb"])
        elsif line == "recent"
          server.run_recent
        elsif line == "uncommitted"
          server.run_uncommitted
        elsif line == "all"
          server.run_tests(["test/unit/**/*_test.rb", "test/functional/**/*_test.rb", "test/integration/**/*_test.rb"])
        else
          server.run_tests([line])
        end
      end

      return true
    end

    # Prints a list of available commands
    def self.help
      puts
      puts "Available commands:"
      puts
      puts "all          # Run all test types (units, functionals, integration)"
      puts "units        # Run unit tests"
      puts "functionals  # Run functional tests"
      puts "integration  # Run integration tests"
      puts "recent       # Run tests for recently changed files"
      puts "uncommitted  # Run tests for uncommitted changes"
      puts "[filename]   # Run the tests contained in the given file"
      puts "reload       # Reload your Rails environment"
      puts "exit         # Exit the console"
      puts
    end
  end
end
