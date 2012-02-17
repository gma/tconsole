module TConsole
  class MiniTestHandler
    def self.run(name_pattern, config)
      args = []
      unless name_pattern.nil?
        args = ["--name", name_pattern]
      end

      # Make sure we have a recent version of minitest, and use it
      if ::MiniTest::Unit.respond_to?(:runner=)
        ::MiniTest::Unit.runner = TConsole::MiniTestUnit.new(config)
      else
        raise "MiniTest v#{MiniTest::Unit::VERSION} is not compatible with tconsole. Please load a more recent version of MiniTest"
      end

      # Run it
      runner = MiniTest::Unit.runner
      runner.run(args)

      # Make sure that minitest doesn't run automatically when the process exits
      patch_minitest

      runner.results
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

    attr_accessor :config, :results

    def initialize(config)
      self.config = config
      self.results = TConsole::TestResult.new

      super()
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
      format = "%d tests, %d assertions, %d failures, %d errors, %d skips"
      io.puts format % [test_count, assertion_count, failures, errors, skips]
    end

    def _run_suite(suite, type)
      @failed_fast ||= false

      filter = options[:filter] || '/./'
      filter = Regexp.new $1 if filter =~ /\/(.*)\//

      assertions = suite.send("#{type}_methods").grep(filter).map do |method|
        if @failed_fast
          0
        else
          inst = suite.new method
          inst._assertions = 0

          # Print the suite name if needed
          if results.add_suite(suite)
            print("\n\n", ::Term::ANSIColor.cyan, suite, ::Term::ANSIColor.reset, "\n")
          end

          @start_time = Time.now
          result = inst.run self
          time = Time.now - @start_time
          results.add_timing(suite, method, time)

          result = "P" if result == "."

          if config.fail_fast && result != "P"
            @failed_fast = true
          end

          output = "#{result} #{method}"

          print COLOR_MAP[result], " #{output}", ::Term::ANSIColor.reset, " #{time}s\n"

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
            results.skips += 1
            return "S" unless @verbose
            "Skipped:\n#{meth}(#{klass}) [#{location e}]:\n#{e.message}\n"
          when MiniTest::Assertion then
            @failures += 1
            results.failures += 1
            results.append_failure_details(klass, meth)
            "Failure:\n#{meth}(#{klass}) [#{location e}]:\n#{e.message}\n"
          else
            @errors += 1
            results.errors += 1
            results.append_failure_details(klass, meth)
            bt = MiniTest::filter_backtrace(e.backtrace).join "\n    "
            "Error:\n#{meth}(#{klass}):\n#{e.class}: #{e.message}\n    #{bt}\n"
          end
      @report << e
      e[0, 1]
    end
  end
end

# Make sure that output is only colored when it should be
Term::ANSIColor::coloring = STDOUT.isatty
