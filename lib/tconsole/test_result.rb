module TConsole
  class TestResult
    # The number of failed tests in the last run
    attr_accessor :failures

    # The number of errors that occurred in the last run
    attr_accessor :errors

    # The number of skipped tests
    attr_accessor :skips

    # Details about the failures in the last run
    attr_accessor :failure_details

    # The suites that we've run
    attr_accessor :suites

    # The timings for the tests we've run
    attr_accessor :timings

    # The element id lookup hash
    attr_accessor :elements

    # Test counts within various suites
    attr_accessor :suite_counts

    def initialize
      self.failures = 0
      self.errors = 0
      self.skips = 0
      self.failures = []
      self.suites = {}
      self.timings = []

      self.suite_counts = {}
      self.elements = {}
    end

    def add_element(suite, method)
      canonical_name = "#{suite}##{method}"

      # Just return the id if we already know about this
      if id = elements[canonical_name]
        return id
      end

      # See if we know about this suite already
      unless suite_id = elements[suite.to_s]
        suite_id = self.suite_counts.length + 1
        elements[suite.to_s] = suite_id
        suite_counts[suite.to_s] ||= 0
      end

      suite_counts[suite.to_s] += 1
      id = "#{suite_id}-#{suite_counts[suite.to_s]}"
      elements[canonical_name] = id

      id
    end

    def add_timing(suite, method, time)
      self.timings << { :suite => suite.to_s, :method => method.to_s, :time => time }
    end
  end
end
