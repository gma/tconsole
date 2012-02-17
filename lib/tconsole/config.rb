module TConsole
  class Config
    # Lets us know if we should include trace output
    attr_accessor :trace

    # Test directory for the app we're testing
    attr_accessor :test_dir

    # Paths to add to the ruby include path
    attr_accessor :include_paths

    # Paths we want to preload
    attr_accessor :preload_paths

    def initialize
      self.trace = false
      self.test_dir = "./test/"
      self.include_paths = ["./test/", "./lib/"]
      self.autoload_paths = []

      @after_load = nil
    end

    def trace?
      self.trace
    end

    # Proc to run after loading the environment
    def after_load(&block)
      @after_load = block
    end

    # Calls the after load callback
    def after_load!
      @after_load.call unless @after_load.nil?
    end
  end
end
