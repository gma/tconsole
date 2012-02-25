module TConsole
  class MiniTestHandler
    def self.run(match_patterns, config)
      # Make sure we have a recent version of minitest, and use it
      if ::MiniTest::Unit.respond_to?(:runner=)
        ::MiniTest::Unit.runner = TConsole::MiniTestUnit.new(match_patterns, config)
      else
        raise "MiniTest v#{MiniTest::Unit::VERSION} is not compatible with tconsole. Please load a more recent version of MiniTest"
      end

      # Run it
      runner = ::MiniTest::Unit.runner
      runner.run

      # Make sure that minitest doesn't run automatically when the process exits
      patch_minitest

      runner.results
    end

    # Preloads our element cache for autocompletion. Assumes tests are already loaded
    def self.preload_elements
      patch_minitest

      results = TConsole::TestResult.new

      suites = ::MiniTest::Unit::TestCase.test_suites
      suites.each do |suite|
        suite.test_methods.map do |method|
          id = results.add_element(suite, method)
        end
      end

      results
    end


    # We're basically breaking MiniTest autorun here, since we want to manually run our
    # tests and Rails relies on autorun
    #
    # A big reason for the need for this is that we're trying to work in the Rake environment
    # rather than rebuilding all of the code in Rake just to get test prep happening
    # correctly.
    def self.patch_minitest
      ::MiniTest::Unit.class_eval do
        alias_method :old_run, :run
        def run(args = [])
          # do nothing
        end
      end
    end
  end

  # Custom minitest runner for tconsole
  class MiniTestUnit < ::MiniTest::Unit
    COLOR_MAP = {
      "S" => ::Term::ANSIColor.cyan,
      "E" => ::Term::ANSIColor.red,
      "F" => ::Term::ANSIColor.red,
      "P" => ::Term::ANSIColor.green
    }

    attr_accessor :match_patterns, :config, :results

    def initialize(match_patterns, config)
      self.match_patterns = match_patterns
      self.match_patterns = [] unless self.match_patterns.is_a?(Array)

      self.config = config
      self.results = TConsole::TestResult.new

      results.suite_counts = config.cached_suite_counts
      results.elements = config.cached_elements

      super()

      # We do this since plugins like turn may have tweaked it
      @@out = $stdout
    end

    def _run_anything(type)
      suites = TestCase.send "#{type}_suites"
      return if suites.empty?

      start = Time.now

      @test_count, @assertion_count = 0, 0
      sync = output.respond_to? :"sync=" # stupid emacs
      old_sync, output.sync = output.sync, true if sync

      results = _run_suites(suites, type)

      @test_count      = results.inject(0) { |sum, (tc, _)| sum + tc }
      @assertion_count = results.inject(0) { |sum, (_, ac)| sum + ac }

      output.sync = old_sync if sync

      t = Time.now - start

      puts
      puts
      puts "Finished #{type}s in %.6fs, %.4f tests/s, %.4f assertions/s." %
        [t, test_count / t, assertion_count / t]

      report.each_with_index do |msg, i|
        puts "\n%3d) %s" % [i + 1, msg]
      end

      puts

      status
    end

    def status(io = self.output)
      format = "%d tests, %d assertions, "

      format << COLOR_MAP["F"] if failures > 0
      format << "%d failures, "
      format << ::Term::ANSIColor.reset if failures > 0

      format << COLOR_MAP["E"] if errors > 0
      format << "%d errors, "
      format << ::Term::ANSIColor.reset if errors > 0

      format << COLOR_MAP["S"] if skips > 0
      format << "%d skips"
      format << ::Term::ANSIColor.reset if skips > 0

      io.puts format % [test_count, assertion_count, failures, errors, skips]
    end

    def _run_suite(suite, type)
      @last_suite ||= nil
      @failed_fast ||= false

      assertions = suite.send("#{type}_methods").map do |method|
        skip = false

        # Get our unique id for this particular element
        id = results.add_element(suite, method)
        suite_id = results.elements[suite.to_s]

        # If we're using failed fast mode and we already failed, just return
        skip = true if @failed_fast

        # If we've got match patterns, see if this matches them
        if !match_patterns.empty?
          match = match_patterns.find do |pattern|
            pattern == suite.to_s || pattern == "#{suite.to_s}##{method.to_s}" || pattern == suite_id.to_s || pattern == id
          end

          skip = true unless !match.nil?
        end

        if skip
          0
        else
          inst = suite.new method
          inst._assertions = 0

          # Print the suite name if needed
          unless @last_suite == suite
            print("\n\n", ::Term::ANSIColor.cyan, suite, ::Term::ANSIColor.reset,
                  ::Term::ANSIColor.magenta, " #{suite_id}", ::Term::ANSIColor.reset, "\n")
            @last_suite = suite
          end

          @start_time = Time.now
          result = inst.run self
          time = Time.now - @start_time
          results.add_timing(suite, method, time)

          result = "P" if result == "."

          results.failures << id unless result == "P"

          if config.fail_fast && result != "P"
            @failed_fast = true
          end

          output = "#{result} #{method}"

          print COLOR_MAP[result], " #{output}", ::Term::ANSIColor.reset, " #{"%0.6f" % time }s ",
            ::Term::ANSIColor.magenta, "#{id}", ::Term::ANSIColor.reset, "\n"

          if @failed_fast
            print "\n", COLOR_MAP["E"], "Halting tests because of failure.", ::Term::ANSIColor.reset, "\n"
          end

          inst._assertions
        end
      end

      return assertions.size, assertions.inject(0) { |sum, n| sum + n }
    end

    def puke(klass, meth, e)
      e = case e
          when MiniTest::Skip then
            @skips += 1
            results.skip_count += 1
            return "S" unless @verbose
            ["S", COLOR_MAP["S"] + "Skipped:\n#{meth}(#{klass})" + ::Term::ANSIColor.reset + " [#{location e}]:\n#{e.message}\n"]
          when MiniTest::Assertion then
            @failures += 1
            results.failure_count += 1
            ["F", COLOR_MAP["F"] + "Failure:\n#{meth}(#{klass})" + ::Term::ANSIColor.reset + " [#{location e}]:\n#{e.message}\n"]
          else
            @errors += 1
            results.error_count += 1
            bt = MiniTest::filter_backtrace(e.backtrace).join "\n    "
            ["E", COLOR_MAP["E"] + "Error:\n#{meth}(#{klass}):\n" + ::Term::ANSIColor.reset + "#{e.class}: #{e.message}\n    #{bt}\n"]
          end
      @report << e[1]
      e[0]
    end
  end
end

# Make sure that output is only colored when it should be
Term::ANSIColor::coloring = STDOUT.isatty
