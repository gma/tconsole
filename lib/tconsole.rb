require "tconsole/version"

require 'readline'
require 'benchmark'

module TConsole
  class Runner
    # Spawns a new environment. Looks at the results of the environment to determine whether to stop or
    # keep running
    def self.run
      stty_save = `stty -g`.chomp

      # We're only going to handle interrupts on the inner process
      trap("SIGINT", "IGNORE");
      running = true

      # A little welcome
      puts
      puts "Welcome to tconsole. Type 'help' for help."
      puts "Press ^C or type 'exit' to quit."

      while running
        read, write = IO.pipe
        pid = fork do
          write.close
          exit run_environment(read) ? 0 : 1
          read.close
        end

        read.close

        while line = Readline.readline("tconsole>", true)
          write.puts(line)
        end

        write.close

        pid, status = Process.wait2(pid)
        running = false if status.exitstatus != 0
      end

      puts
      puts "Exiting. Bye!"
      system("stty", stty_save);
    end

    # Starts our Rails environment and listens for console commands
    # Returns true if we should keep running or false if we need to exit
    def self.run_environment(read)

      trap("SIGINT", "SYSTEM_DEFAULT");

      puts
      puts "Loading Rails environment..."
      time = Benchmark.realtime do
        begin
          # Ruby environment loading is shamelessly borrowed from spork
          ENV["RAILS_ENV"] ||= "test"
          $:.unshift("./test")

          require 'rake'
          Rake.application.init
          Rake.application.load_rakefile
          Rake.application.invoke_task("test:prepare")
        rescue Exception => e
          puts "Error: Loading your environment failed."
          puts "    #{e.message}"
          return false
        end
      end

      puts "Environment loaded in #{time}s."
      puts

      while line = read.read
        result = process_command(line)

        return false if !result
      end

      return false
    end

    # Taks an array of globs and loads all of the files in the globs
    # and then runs the tests in those files
    def self.run_tests(globs)
      time = Benchmark.realtime do
        pid = fork do

          puts "Running tests..."
          puts

          paths = []
          globs.each do |glob|
            paths.concat(Dir.glob(glob))
          end

          paths.each do |path|
            require File.realpath(path)
          end

          if defined? ActiveRecord
            ActiveRecord::Base.connection.reconnect!
          end
        end

        Process.wait2(pid)
      end

      puts
      puts "Test time (including load): #{time}s"
      puts
    end

    # Processes a command that was submitted
    # Returns false if the command would cause us to exit, true otherwise
    def process_command(line)
      if line == "exit"
        return false
      elsif line == "reload"
        return true
      elsif line == "help"
        help
      elsif line == "units"
        run_tests(["test/unit/**/*_test.rb"])
      elsif line == "functionals"
        run_tests(["test/functional/**/*_test.rb"])
      elsif line == "integration"
        run_tests(["test/integration/**/*_test.rb"])
      elsif line == "all"
        run_tests(["test/unit/**/*_test.rb", "test/functional/**/*_test.rb", "test/integration/**/*_test.rb"])
      else
        run_tests([line])
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
      puts "[filename]   # Run the tests contained in the given file"
      puts "reload       # Reload your Rails environment"
      puts "exit         # Exit the console"
      puts
    end
  end
end
