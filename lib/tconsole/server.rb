module TConsole
  class Server
    attr_accessor :config, :last_result

    def initialize(config)
      self.config = config
      self.last_result = TConsole::TestResult.new
    end

    # Basically just a noop that helps us figure out if we're connected or not
    def connected?
      true
    end

    def stop
      DRb.stop_service
    end

    def load_environment
      result = false

      time = Benchmark.realtime do
        puts
        puts "Loading environment..."

        begin
          # Append our include paths
          config.include_paths.each do |include_path|
            $:.unshift(include_path)
          end

          config.before_load!

          # Load our preload files
          config.preload_paths.each do |preload_path|
            require preload_path
          end

          config.after_load!

          result = true
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

    # Loads the files that match globs and then executes tests against them. Limit tests
    # with class names, method names, and test ids using match_patterns.
    def run_tests(globs, match_patterns, message = "Running tests...")
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
            config.trace("Requested path `#{path}` doesn't exist.") unless File.exist?(path)
            require File.expand_path(path)
          end

          config.trace("Running before_test_run callback")
          config.before_test_run!
          config.trace("Completed before_test_run callback")

          if defined?(::MiniTest)
            config.trace("Detected minitest.")
            require File.join(File.dirname(__FILE__), "minitest_handler")

            config.trace("Running tests.")
            result = MiniTestHandler.run(match_patterns, config)
            config.trace("Finished running tests.")

            config.trace("Writing test results back to server.")
            write.puts([Marshal.dump(result)].pack("m"))
            config.trace("Finished writing test results to server.")

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
          config.trace("Reading test results from console.")
          self.last_result = Marshal.load(response.unpack("m")[0])
          config.cache_test_ids(self.last_result)
          config.trace("Finished reading test results from console.")
        rescue => e
          config.trace("Exception: #{e.message}")
          config.trace("==== Backtrace ====")
          config.trace(e.backtrace.join("\n"))
          config.trace("==== End Backtrace ====")

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

    # Runs all tests against the match patterns given
    def run_all_tests(match_patterns = nil)
      run_tests(config.file_sets["all"], match_patterns)
    end

    # Runs a file set out of the config
    def run_file_set(set)
      run_tests(config.file_sets[set], nil)
    end

    def run_failed
      if last_result.failures.empty?
        puts "No tests failed in your last run, or you haven't run any tests in this session yet."
        puts
      else
        run_tests(config.file_sets["all"], last_result.failures)
      end
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

    def set(key, value)
      if key == "fast"
        value.downcase!
        if value == "on" || value == "true" || value == "yes"
          config.fail_fast = true
        else
          config.fail_fast = false
        end

        puts "Fail Fast is now #{config.fail_fast ? "on" : "off"}"
        puts
      else
        puts "#{key} isn't an available runtime setting."
        puts
      end
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
