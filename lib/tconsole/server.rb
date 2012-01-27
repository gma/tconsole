module TConsole
  class Server
    attr_accessor :config, :last_failed

    def initialize(config)
      self.config = config
      self.last_failed = []
    end

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
          Rake.application.invoke_task("db:test:load")
          Rake.application.invoke_task("test:prepare")
        rescue Exception => e
          puts "Error - Loading your environment failed: #{e.message}"
          if config[:trace] == true
            puts
            puts "    #{e.backtrace.join("\n    ")}"
          end

          return false
        end
      end

      puts "Environment loaded in #{time}s."
      puts

      return true
    end

    def run_tests(globs, name_pattern, message = "Running tests...")
      read, write = IO.pipe
      time = Benchmark.realtime do
        fork do

          puts message
          puts

          paths = []
          globs.each do |glob|
            paths.concat(Dir.glob(glob))
          end

          if defined? ActiveRecord
            ActiveRecord::Base.connection.reconnect!
          end

          paths.each do |path|
            require File.realpath(path)
          end

          if defined?(MiniTest)
            read.close
            require File.join(File.dirname(__FILE__), "minitest_handler")
            MiniTestHandler.run(name_pattern)
            write.puts [Marshal.dump(self.last_failed)].pack("m")
          elsif defined?(Test::Unit)
            puts "Sorry, but tconsole doesn't support Test::Unit yet"
            return
          elsif defined?(RSpec)
            puts "Sorry, but tconsole doesn't support RSpec yet"
            return
          end
        end

        Process.waitall
      end

      write.close
      begin
        self.last_failed = Marshal.load(read.read.unpack("m")[0])
      rescue ArgumentError
        #do nothing, there are no failed tests
      end
      puts
      puts "Test time (including load): #{time}s"
      puts
    end

    # This code is from the rails test:recents command
    def run_recent(test_pattern)
      touched_since = Time.now - 600 # 10 minutes ago
      files = recent_files(touched_since, "app/models/**/*.rb", "test/unit")
      files.concat(recent_files(touched_since, "app/controllers/**/*.rb", "test/functional"))

      message = "Running #{files.length} #{files.length == 1 ? "test file" : "test files"} based on changed files..."
      run_tests(files, test_pattern, message)
    end

    def run_failed(test_pattern)
      file_names = last_failed.map {|class_name| class_name.tableize.singularize}
      files_to_rerun = file_names.map {|file| (file.match(/controller/)) ? "/functionals/#{file}.rb" : "/units/#{file}.rb"}
      message = "Running last failed tests"
      run_tests(files_to_rerun, test_pattern, message)
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

    # Based on the code from rake test:uncommitted in Rails
    def run_uncommitted(test_pattern)
      if File.directory?(".svn")
        changed_since_checkin = silence_stderr { `svn status` }.split.map { |path| path.chomp[7 .. -1] }
      elsif File.directory?(".git")
        changed_since_checkin = silence_stderr { `git ls-files --modified --others` }.split.map { |path| path.chomp }
      else
        puts "Not a Subversion or Git checkout."
        return
      end

      models      = changed_since_checkin.select { |path| path =~ /app[\\\/]models[\\\/].*\.rb$/ }
      controllers = changed_since_checkin.select { |path| path =~ /app[\\\/]controllers[\\\/].*\.rb$/ }

      unit_tests       = models.map { |model| "test/unit/#{File.basename(model, '.rb')}_test.rb" }
      functional_tests = controllers.map { |controller| "test/functional/#{File.basename(controller, '.rb')}_test.rb" }
      files = (unit_tests + functional_tests).uniq.select { |file| File.exist?(file) }

      message = "Running #{files.length} #{files.length == 1 ? "test file" : "test files"} based on uncommitted changes..."
      run_tests(files, test_pattern, message)
    end

    def run_info
      puts "Defined Constants:"
      puts Module.constants.sort.join("\n")
      puts
      puts
    end
  end
end
