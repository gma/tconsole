module TConsole
  class Server
    attr_accessor :config, :reporter, :last_result

    def initialize(config, reporter)
      self.config = config
      self.reporter = reporter
      self.last_result = TConsole::TestResult.new
    end
    
    # Internal: Outputs a message that a feature hasn't been implemented
    def not_implemented
      reporter.error("This feature hasn't been implemented yet.")
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

    # Preloads our autocomplete cache
    def preload_test_ids
      # Does nothing by default
    end

    # Runs all tests against the match patterns given
    def run_all_tests(match_patterns = nil)
      reporter.error("This feature hasn't been implemented yet.")
    end

    # Runs a file set out of the config
    def run_file_set(set)
      reporter.error("This feature hasn't been implemented yet.")
    end

    def run_failed
      reporter.error("This feature hasn't been implemented yet.")
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
