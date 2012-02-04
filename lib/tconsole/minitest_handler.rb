module TConsole
  class MiniTestHandler
    def self.run(name_pattern)
      args = []
      unless name_pattern.nil?
        args = ["--name", name_pattern]
      end

      runner = MiniTest::Unit.new
      runner.run(args)

      result = TConsole::TestResult.new
      result.failures = runner.failures
      result.errors = runner.errors

      if runner.failures > 0 || runner.errors > 0
        result.failure_details = runner.report.map do |item|
          match = item.match(/(\w+)\((\w+)\)/)

          [match[2], match[1]]
        end
      end

      patch_minitest

      result
    end

    # We're basically breaking MiniTest autorun here, since we want to manually run our
    # tests and Rails relies on autorun
    #
    # A big reason for the need for this is that we're trying to work in the Rake environment
    # rather than rebuilding all of the code in Rake just to get test prep happening
    # correctly.
    def self.patch_minitest
      MiniTest::Unit.class_eval do
        alias_method :old_run, :run
        def run(args = [])
          # do nothing
        end
      end
    end
  end
end
