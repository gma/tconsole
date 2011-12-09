require "tconsole/version"

require 'readline'
require 'benchmark'

module TConsole
  class Runner
    # Spawns a new environment. Looks at the results of the environment to determine whether to stop or
    # keep running
    def self.run
      running = true

      while running
        read, write = IO.pipe
        pid = fork do
          response = run_environment(write)
          write.puts [Marshal.dump(response)].pack("m")
        end
        write.close

        response = read.read
        Process.wait2(pid)
        running = Marshal.load(response.unpack("m")[0])
        read.close
      end

      puts
      puts "Exiting. Bye!"
    end

    # Starts our Rails environment and listens for console commands
    # Returns true if we should keep running or false if we need to exit
    def self.run_environment(write)

      puts
      puts "Loading Ruby environment..."
      time = Benchmark.realtime do
        # Ruby environment loading is shamelessly borrowed from spork
        ENV["RAILS_ENV"] ||= "test"
        $:.unshift("./test")

        require "./config/application"
        ::Rails.application
      end

      puts "Environment loaded in #{time}s."
      puts

      # Store the state of the terminal
      stty_save = `stty -g`.chomp
      #trap('INT') { system('stty', stty_save); exit }


      while line = Readline.readline('> ', true)
        if line == "exit"
          return false
        elsif line == "reload"
          return true
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
      end
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
        end

        Process.wait2(pid)
      end

      puts
      puts "Test time (including load): #{time}s"
      puts
    end
  end
end
