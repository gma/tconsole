module TConsole
  class TestResult
    # The number of failed tests in the last run
    attr_accessor :failures

    # The number of errors that occurred in the last run
    attr_accessor :errors

    # Details about the failures in the last run
    attr_accessor :failure_details

    def initialize
      self.failures = 0
      self.errors = 0
      self.failure_details = []
    end
  end
end
