module TConsole
  class Server
    attr_accessor :config, :last_result

    def initialize(config)
      self.config = config
      self.last_result = TConsole::TestResult.new
    end

    def stop
      DRb.stop_service
    end

    def load_environment
      result = false

      time = Benchmark.realtime do

        begin
          if is_rails?
            result = load_rails_environment
          else
            result = load_non_rails_environment
          end
        rescue Exception => e
          puts "Error - Loading your environment failed: #{e.message}"
          if config.trace?
            puts
            puts "    #{e.backtrace.join("\n    ")}"
          end

          return false
        end
      end

      puts "Environment loaded in #{time}s."
      puts

      result
    end

    def is_rails?
      @rails ||= !!File.exist?("./config/application.rb")
    end

    def load_rails_environment
      puts
      puts "Loading Rails environment..."

      # Ruby environment loading is shamelessly borrowed from spork
      ENV["RAILS_ENV"] ||= "test"
      $:.unshift("./test")

      # This is definitely based on Sporks rails startup code. I tried initially to use Rake to get things done
      # and match the test environment a bit better, but it didn't work out well at all
      # TODO: Figure out how ot get rake db:test:load and rake test:prepare working in this context
      require "./config/application"
      ::Rails.application
      ::Rails::Engine.class_eval do
        def eager_load!
          # turn off eager_loading
        end
      end

      true
    end

    def load_non_rails_environment
      $:.unshift("./lib")
      $:.unshift("./test")

      puts
      puts "Loading environment..."

      true
    end

    def run_tests(globs, name_pattern, message = "Running tests...")
      time = Benchmark.realtime do
        # Pipe for communicating with child so we can get its results back
        read, write = IO.pipe

        fork do
          read.close

          puts message
          puts

          paths = []
          globs.each do |glob|
            paths.concat(Dir.glob(glob))
          end

          paths.each do |path|
            require File.expand_path(path)
          end

          if defined? ::ActiveRecord
            ::ActiveRecord::Base.clear_active_connections!
            ::ActiveRecord::Base.establish_connection
          end

          if defined?(::MiniTest)
            require File.join(File.dirname(__FILE__), "minitest_handler")

            result = MiniTestHandler.run(name_pattern)

            write.puts([Marshal.dump(result)].pack("m"))

          elsif defined?(::Test::Unit)
            puts "Sorry, but tconsole doesn't support Test::Unit yet"
            return
          elsif defined?(::RSpec)
            puts "Sorry, but tconsole doesn't support RSpec yet"
            return
          end
        end

        write.close
        response = read.read
        begin
          self.last_result = Marshal.load(response.unpack("m")[0])
        rescue
          puts "ERROR: Unable to process test results."
          puts

          # Just in case anything crazy goes down with marshalling
          self.last_result = TConsole::TestResult.new
        end

        read.close

        Process.waitall
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

    def run_failed
      file_names = last_result.failure_details.map { |detail| filenameify(detail[:class]) }
      files_to_rerun = []

      files_to_rerun << file_names.map {|file| (file.match(/controller/)) ? "test/functional/#{file}.rb" : "test/unit/#{file}.rb"}
      run_tests(files_to_rerun, nil, "Running last failed tests: #{files_to_rerun.join(", ")}")
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

    def show_performance(limit = nil)

      limit = limit.to_i
      limit = last_result.timings.length if limit == 0

      sorted_timings = last_result.timings.sort_by { |timing| timing[:time] }

      puts
      puts "Timings from last run:"
      puts

      if sorted_timings.length == 0
        puts "No timing data available. Be sure you've run some tests."
      else
        sorted_timings.reverse[0, limit].each do |timing|
          puts "#{timing[:time]}s #{timing[:suite]}##{timing[:method]}"
        end
      end

      puts
    end

    def filenameify(klass_name)
      result = ""
      first = true
      klass_name.chars do |char|
        new = char.downcase!
        if new.nil?
          result << char
        elsif first
          result << new
        else
          result << "_#{new}"
        end

        first = false
      end

      result
    end

    # Totally yanked from the Rails test tasks
    def silence_stderr
      old_stderr = STDERR.dup
      STDERR.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
      STDERR.sync = true
      yield
    ensure
      STDERR.reopen(old_stderr)
    end
  end
end
