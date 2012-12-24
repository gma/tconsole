module TConsole
  class Config
    # Lets us know if we should include trace output
    attr_accessor :trace_execution

    # Lets us know if we should include trace output.
    # Defaults to false.
    attr_accessor :trace

    # Test directory for the app we're testing.
    # Defaults to ./test.
    attr_accessor :test_dir

    # Paths to add to the ruby include path.
    # Defaults to ./test, ./lib
    attr_accessor :include_paths

    # Paths we want to preload. Defaults to nil.
    attr_accessor :preload_paths

    # Whether or not our test runs should stop when the first
    # test fails. Defaults to false.
    attr_accessor :fail_fast

    # Defines the file set commands that are available
    attr_accessor :file_sets

    # Counts of tests in suites
    attr_accessor :cached_suite_counts

    # Element names we know
    attr_accessor :cached_elements

    # First command to run when tconsole loads
    attr_accessor :run_command

    # Only runs the command passed on the command line, and then exits
    attr_accessor :once

    def initialize(argv = [])
      self.trace_execution = false
      self.test_dir = "test"
      self.include_paths = ["./test", "./lib"]
      self.preload_paths = []
      self.fail_fast = false
      self.file_sets = {
        "all" => ["#{test_dir}/**/*_test.rb"]
      }

      # load any args into this config that were passed
      load_args(argv)

      @after_load = nil
      @before_load = nil
      @before_test_run = nil

      @cached_suite_counts = {}
      @cached_elements = {}
    end

    def option_parser
      @option_parser ||= OptionParser.new do |opts|
        opts.on("-t", "--trace", "Enable verbose output.") do
          self.trace_execution = true
        end

        opts.on("-o", "--once", "Run whatever command is passed and then exit.") do
          self.once = true
        end
      end
    end

    # Public: Loads any passed command line arguments into the config.
    #
    # argv  - The array of command line arguments we're loading
    def load_args(argv)
      args = argv.clone

      option_parser.parse!(args)
      self.run_command = args.join(" ")
    end

    def trace?
      self.trace_execution
    end

    def fail_fast?
      self.fail_fast
    end

    # Code to run before loading the environment
    def before_load(&block)
      @before_load = block
    end

    # Calls the before load callback
    def before_load!
      @before_load.call unless @before_load.nil?
    end

    # Code to run after loading the environment
    def after_load(&block)
      @after_load = block
    end

    # Calls the after load callback
    def after_load!
      @after_load.call unless @after_load.nil?
    end

    # Calls before each test execution
    def before_test_run(&block)
      @before_test_run = block
    end

    def before_test_run!
      @before_test_run.call unless @before_test_run.nil?
    end

    def cache_test_ids(result)
      self.cached_suite_counts = result.suite_counts
      self.cached_elements = result.elements
    end

    # Returns true if this config is valid or false otherwise
    def validation_errors
      errors = []

      unless Dir.exists?(test_dir)
        errors << "Couldn't find test directory `#{test_dir}`. Exiting."
      end

      unless file_sets.is_a?(Hash) && !file_sets["all"].nil?
        errors << "No `all` file set is defined in your configuration. Exiting."
      end

      errors
    end

    # Loads up a config file
    def self.load_config(path)
      if File.exist?(path)
        load path
      end
    end

    # Saves a configuration block that we can apply to the configuration once it's
    # loaded
    def self.run(&block)
      @loaded_configs ||= []
      @loaded_configs << block
    end

    def self.clear_loaded_configs
      @loaded_configs = nil
    end

    # Returns an appropriate tconsole config based on the environment
    def self.configure(argv = [])
      config = Config.new(argv)

      if is_rails?
        config.preload_paths = ["./config/application"]
        config.include_paths = ["./test"]
        config.file_sets = {
          "all" => ["#{config.test_dir}/unit/**/*_test.rb", "#{config.test_dir}/functional/**/*_test.rb",
            "#{config.test_dir}/integration/**/*_test.rb"],
          "units" => ["#{config.test_dir}/unit/**/*_test.rb"],
          "unit" => ["#{config.test_dir}/unit/**/*_test.rb"],
          "functionals" => ["#{config.test_dir}/functional/**/*_test.rb"],
          "functional" => ["#{config.test_dir}/functional/**/*_test.rb"],
          "integration" => ["#{config.test_dir}/integration/**/*_test.rb"]
        }


        config.before_load do
          ENV["RAILS_ENV"] ||= "test"
        end

        config.after_load do
          ::Rails.application
          ::Rails::Engine.class_eval do
            def eager_load!
              # turn off eager_loading
            end
          end
        end

        config.before_test_run do
          if defined? ::ActiveRecord
            ::ActiveRecord::Base.clear_active_connections!
            ::ActiveRecord::Base.establish_connection
          end
        end
      end

      @loaded_configs ||= []
      @loaded_configs.each do |block|
        block.call(config)
      end

      config
    end

    def self.is_rails?
      @rails ||= !!File.exist?("./config/application.rb")
    end
  end
end
