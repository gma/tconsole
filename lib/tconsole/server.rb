module TConsole
  class Server
    attr_accessor :config, :last_result

    def initialize(config)
      self.config = config
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

        preload_test_ids
      end

      puts "Environment loaded in #{"%0.6f" % time}s."
      puts

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
        config.trace("Reading result from fork.")
        Marshal.load(response.unpack("m")[0])
      rescue => e
        config.trace("Problem reading result from fork. Returning nil.")
        config.trace(e.message)
        nil
      end
    end

    # Loads the files that match globs and then executes tests against them. Limit tests
    # with class names, method names, and test ids using match_patterns.
    def run_tests(globs, match_patterns, message = "Running tests...")
      time = Benchmark.realtime do
        puts message
        puts

        paths = []
        globs.each do |glob|
          paths.concat(Dir.glob(glob))
        end

        if paths.length == 0
          puts ::Term::ANSIColor.yellow("No test files match your requested test set: #{globs.join(",")}.")
          puts ::Term::ANSIColor.yellow("Skipping execution.")
          return nil
        end

        self.last_result = run_in_fork do

          paths.each do |path|
            config.trace("Requested path `#{path}` doesn't exist.") unless File.exist?(path)
            require File.expand_path(path)
          end

          config.trace("Running before_test_run callback")
          config.before_test_run!
          config.trace("Completed before_test_run callback")

          result = nil
          if defined?(::MiniTest)
            config.trace("Detected minitest.")
            require File.join(File.dirname(__FILE__), "minitest_handler")

            config.trace("Running tests.")
            result = MiniTestHandler.run(match_patterns, config)
            config.trace("Finished running tests.")
          elsif defined?(::Test::Unit)
            puts "Sorry, but tconsole doesn't support Test::Unit yet"
          elsif defined?(::RSpec)
            puts "Sorry, but tconsole doesn't support RSpec yet"
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

      puts
      puts "Test time (including load): #{"%0.6f" % time}s"
      puts
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
          puts "#{"%0.6f" % timing[:time]}s #{timing[:suite]}##{timing[:method]}"
        end
      end

      puts
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

          puts ::Term::ANSIColor.green + "Fail Fast is now #{config.fail_fast ? "on" : "off"}" + ::Term::ANSIColor.reset
          puts
        else
          puts ::Term::ANSIColor.green + "Fail fast is currently #{config.fail_fast ? "on" : "off"}" + ::Term::ANSIColor.reset
          puts
        end
      else
        puts ::Term::ANSIColor.yellow + "I don't know how to set `#{key}`." + ::Term::ANSIColor.reset + " Usage: set {key} {value}"
        puts
      end
    end
  end
end
