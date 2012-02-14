module TConsole
  class MiniTestHandler
    def self.run(name_pattern)
      args = []
      unless name_pattern.nil?
        args = ["--name", name_pattern]
      end

      # Make sure we have a recent version of minitest, and use it
      if ::MiniTest::Unit.respond_to?(:runner=)
        ::MiniTest::Unit.runner = TConsole::MiniTestUnit.new
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
    attr_accessor :results

    def initialize
      self.results = TConsole::TestResult.new

      super
    end

    def _run_suite(suite, type)
      filter = options[:filter] || '/./'
      filter = Regexp.new $1 if filter =~ /\/(.*)\//

      assertions = suite.send("#{type}_methods").grep(filter).map { |method|
        inst = suite.new method
        inst._assertions = 0

        # Print the suite name if needed
        puts suite if results.add_suite(suite)

        @start_time = Time.now
        result = inst.run self
        time = Time.now - @start_time

        print result

        inst._assertions
      }

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
