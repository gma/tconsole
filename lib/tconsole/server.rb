module TConsole
  class Server
    def stop
      DRb.stop_service
    end

    def load_environment
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

      return true
    end

    def run_tests(globs)
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
  end
end
