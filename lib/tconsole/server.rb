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

    # This code is from the rails test:recents command
    def run_recent
      touched_since = Time.now - 600 # 10 minutes ago
      files = recent_files(touched_since, "app/models/**/*.rb", "test/unit")
      files.concat(recent_files(touched_since, "app/controllers/**/*.rb", "test/functional"))

      run_tests(files)
    end

    def recent_files(touched_since, source_pattern, test_path)
      Dir.glob(source_pattern).map do |path|
        if File.mtime(path) > touched_since
          tests = []
          source_dir = File.dirname(path).split("/")
          source_file = File.basename(path, '.rb')

          # Support subdirs in app/models and app/controllers
          modified_test_path = source_dir.length > 2 ? "#{test_path}/" << source_dir[1..source_dir.length].join('/') : test_path

          # For modified files in app/ run the tests for it. ex. /test/functional/account_controller.rb
          test = "#{modified_test_path}/#{source_file}_test.rb"
          tests.push test if File.exist?(test)

          # For modified files in app, run tests in subdirs too. ex. /test/functional/account/*_test.rb
          test = "#{modified_test_path}/#{File.basename(path, '.rb').sub("_controller","")}"
          File.glob("#{test}/*_test.rb").each { |f| tests.push f } if File.exist?(test)

          return tests

        end
      end.flatten.compact
    end
  end
end
