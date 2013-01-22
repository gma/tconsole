module TConsole
  class RSpecServer < Server

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

          # Make sure rspec is loaded up
          require 'rspec'
          
          paths.each do |path|
            reporter.trace("Requested path `#{path}` doesn't exist.") unless File.exist?(path)
            require File.expand_path(path)
          end

          reporter.trace("Running before_test_run callback")
          config.before_test_run!
          reporter.trace("Completed before_test_run callback")

          result = nil
          if defined?(::RSpec)
            reporter.trace("Detected rspec.")
            
            reporter.trace("Running tests.")

            # Handle trapping interrupts
            trap("SIGINT") do
              reporter.warn
              reporter.warn("Trapped interrupt. Halting tests.")
            end
            
            # Actually run the tests!
            configuration = RSpec::configuration
            world = RSpec::world
            options = RSpec::Core::ConfigurationOptions.new([])
            options.parse_options
            
            configuration.error_stream = STDERR
            configuration.output_stream = STDOUT
            
            options.configure(configuration)
            
            configuration.files_to_run = paths
            
            configuration.reporter.report(world.example_count, configuration.randomize? ? configuration.seed : nil) do |reporter|
                begin
                    configuration.run_hook(:before, :suite)
                    world.example_groups.ordered.map {|g| g.run(reporter)}.all? ? 0 : configuration.failure_exit_code
                ensure
                    configuration.run_hook(:after, :suite)
                end    
            end
            
            # Patch RSpec to disable autorun
            ::RSpec::Core::Runner.class_eval do
              def self.run(args = [], err=$stderr, out=$stdout)
                # do nothing
              end
            end

            reporter.trace("Finished running tests.")
          end

          nil
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
      result = nil
      # result = run_in_fork do
      #   paths = []
      #   config.file_sets["all"].each do |glob|
      #     paths.concat(Dir.glob(glob))
      #   end
      # 
      #   paths.each { |path| require File.expand_path(path) }
      # 
      #   require File.join(File.dirname(__FILE__), "minitest_handler")
      #   MiniTestHandler.preload_elements
      # end

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
  end
end
