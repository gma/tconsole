require "tconsole/version"
require "tconsole/server"
require "tconsole/test_result"
require "tconsole/util"

require "readline"
require "benchmark"
require "drb/drb"
require "term/ansicolor"

Readline.completion_append_character = ""

# Proc for helping us figure out autocompletes
Readline.completion_proc = Proc.new do |str|
  known_commands = TConsole::Console::KNOWN_COMMANDS.grep(/^#{Regexp.escape(str)}/)

  files = Dir[str+'*'].grep(/^#{Regexp.escape(str)}/)
  formatted_files = files.collect do |filename| 
    if File.directory?(filename)
      filename + File::SEPARATOR
    else
      filename
    end
  end

  known_commands.concat(formatted_files)
end

module TConsole
  class Runner

    # Spawns a new environment. Looks at the results of the environment to determine whether to stop or
    # keep running
    def self.run(argv)
      stty_save = `stty -g`.chomp

      running = true
      trap("SIGINT", "SYSTEM_DEFAULT")

      # A little welcome
      puts
      puts "Welcome to tconsole (v#{TConsole::VERSION}). Type 'help' for help or 'exit' to quit."

      # Set up our console input handling and history
      console = Console.new

      # set up the config
      config = {:trace => false}
      config[:trace] = true if argv.include?("--trace")

      # Start the server
      while running
        # ignore ctrl-c during load, since things can get kind of messy if we don't

        server_pid = fork do
          begin
            server = Server.new(config)

            drb_server = DRb.start_service("drbunix:/tmp/tconsole.#{Process.pid}", server)
            DRb.thread.join
          rescue Interrupt
            # do nothing here since the outer process will shut things down for us
          end
        end

        # Set up our client connection to the server
        server = DRbObject.new_with_uri("drbunix:/tmp/tconsole.#{server_pid}")

        loaded = false
        wait_until = Time.now + 10
        until loaded || Time.now > wait_until
          # Give drb a second to get set up
          sleep(1)

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
    KNOWN_COMMANDS = ["exit", "reload", "help", "units", "functionals", "integration", "recent", "uncommitted", "all", "info", "!failed", "!timings"]

    def initialize
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
      puts "!failed                     # Runs the last set of failing tests"
      puts "!timings [limit]            # Lists the timings for the last test run, sorted."
      puts "[filename] [test_pattern]   # Run the tests contained in the given file"
      puts "reload                      # Reload your Rails environment"
      puts "exit                        # Exit the console"
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


