module MiniTest
  class Unit

    # We're basically breaking MiniTest autorun here, since we want to manually run our
    # tests and Rails relies on autorun
    #
    # A big reason for the need for this is that we're trying to work in the Rake environment
    # rather than rebuilding all of the code in Rake just to get test prep happening
    # correctly.
    alias :old_run :_run
    def _run(options)
      unless @@already_ran
        old_run(options)
      end
      @@already_ran = true
    end
  end
end
