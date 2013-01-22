module TConsole
  class Server
    attr_accessor :config, :reporter, :last_result

    def initialize(config, reporter)
      self.config = config
      self.reporter = reporter
      self.last_result = TConsole::TestResult.new
    end

    # Processes the message sent from the console
    def handle(message)
      action = message[:action]
      args = message[:args]

      send(action, *args)
    end

    def stop
      Kernel.exit(0)
    end

    def load_environment
      result = false

      time = Benchmark.realtime do
        reporter.info
        reporter.info("Loading environment...")

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
          reporter.error("Error - Loading your environment failed: #{e.message}")
          reporter.trace_backtrace(e)
          return false
        end

        preload_test_ids
      end

      reporter.info("Environment loaded in #{"%0.6f" % time}s.")
      reporter.info

      result
    end

    # Returns an array of possible completions based on the available element data
    def autocomplete(text)
      config.cached_elements.keys.grep(/^#{Regexp.escape(text)}/)
    end

    # Runs the given code in a block and returns the result of the code in the block.
    # The block's result needs to be marshallable. Otherwise, nil is returned.
    def run_in_fork(&block)
     # Pipe for communicating with child so we can get its results back
      read, write = IO.pipe

      pid = fork do
        read.close

        result = block.call

        write.puts([Marshal.dump(result)].pack("m0"))
      end

      write.close
      response = read.read
      read.close
      Process.wait(pid)

      begin
        reporter.trace("Reading result from fork.")
        Marshal.load(response.unpack("m")[0])
      rescue => e
        reporter.trace("Problem reading result from fork. Returning nil.")
        reporter.trace(e.message)
        nil
      end
    end

    # Loads the files that match globs and then executes tests against them. Limit tests
    # with class names, method names, and test ids using match_patterns.
    def run_tests(globs, match_patterns, message = "Running tests...")
      time = Benchmark.realtime do
        reporter.info(message)
        reporter.info

        paths = []
        globs.each do |glob|
          paths.concat(Dir.glob(glob))
        end

        if paths.length == 0
          reporter.warn("No test files match your requested test set: #{globs.join(",")}.")
          reporter.warn("Skipping execution.")
          return nil
        end

        self.last_result = run_in_fork do

          paths.each do |path|
            reporter.trace("Requested path `#{path}` doesn't exist.") unless File.exist?(path)
            require File.expand_path(path)
          end

          reporter.trace("Running before_test_run callback")
          config.before_test_run!
          reporter.trace("Completed before_test_run callback")

          result = nil
          if defined?(::MiniTest)
            reporter.trace("Detected minitest.")
            require File.join(File.dirname(__FILE__), "minitest_handler")

            reporter.trace("Running tests.")
            runner = MiniTestHandler.setup(match_patterns, config)

            # Handle trapping interrupts
            trap("SIGINT") do
              reporter.warn
              reporter.warn("Trapped interrupt. Halting tests.")

              runner.interrupted = true
            end

            runner.run

            result = runner.results

            # Make sure minitest doesn't run automatically
            MiniTestHandler.patch_minitest

            reporter.trace("Finished running tests.")

            if runner.interrupted
              reporter.error("Test run was interrupted.")
            end

          elsif defined?(::Test::Unit)
            reporter.error("Sorry, but tconsole doesn't support Test::Unit yet")
          elsif defined?(::RSpec)
            reporter.error("Sorry, but tconsole doesn't support RSpec yet")
          end

          result
        end

        if self.last_result == nil
          # Just in case anything crazy goes down with marshalling
          self.last_result = TConsole::TestResult.new
        end

        config.cache_test_ids(self.last_result)

        true
      end

      reporter.info
      reporter.info("Tests ran in #{"%0.6f" % time}s. Finished at #{Time.now.strftime('%Y-%m-%d %l:%M:%S %p')}.")
      reporter.info
    end

    # Preloads our autocomplete cache
    def preload_test_ids
      result = run_in_fork do
        paths = []
        config.file_sets["all"].each do |glob|
          paths.concat(Dir.glob(glob))
        end

        paths.each { |path| require File.expand_path(path) }

        require File.join(File.dirname(__FILE__), "minitest_handler")
        MiniTestHandler.preload_elements
      end

      config.cache_test_ids(result) unless result.nil?
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
        reporter.info("No tests failed in your last run, or you haven't run any tests in this session yet.")
        reporter.info
      else
        run_tests(config.file_sets["all"], last_result.failures)
      end
    end

    def run_info
      reporter.info("Defined Constants:")
      reporter.info(Module.constants.sort.join("\n"))
      reporter.info
      reporter.info("Configuration:")
      reporter.info("Mode: #{config.mode}")
      reporter.info()
      reporter.info
    end

    def show_performance(limit = nil)

      limit = limit.to_i
      limit = last_result.timings.length if limit == 0

      sorted_timings = last_result.timings.sort_by { |timing| timing[:time] }

      reporter.info
      reporter.info("Timings from last run:")
      reporter.info

      if sorted_timings.length == 0
        reporter.error("No timing data available. Be sure you've run some tests.")
      else
        sorted_timings.reverse[0, limit].each do |timing|
          reporter.timing(timing, last_result.elements[timing[:name]])
        end
      end

      reporter.info
    end

    def set(key, value)
      if key == "fast"
        if !value.nil?
          value.downcase!
          if ["on", "true", "yes"].include?(value)
            config.fail_fast = true
          else
            config.fail_fast = false
          end

          reporter.exclaim("Fail Fast is now #{config.fail_fast ? "on" : "off"}")
          reporter.exclaim
        else
          reporter.exclaim("Fail fast is currently #{config.fail_fast ? "on" : "off"}")
          reporter.exclaim
        end
      else
        reporter.warn("I don't know how to set `#{key}`.")
        reporter.info("Usage: set {key} {value}")
        reporter.warn
      end
    end
  end
end
