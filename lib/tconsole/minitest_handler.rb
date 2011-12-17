module TConsole
  class MiniTestHandler
    def self.run(options)
      if options[:test_pattern]
        args = ["--name", options[:test_pattern]]
      else
        args = []
      end

      MiniTest::Unit.runner.run(args)

      patch_minitest
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
