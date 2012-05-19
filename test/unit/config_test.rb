require 'test_helper'

module TConsole
  class ConfigTest < MiniTest::Unit::TestCase

    a "Config" do
      before do
        @config = TConsole::Config.new([])
      end

      it "should have appropriate defaults" do
        assert_equal false, @config.trace_execution
        assert_equal "./test", @config.test_dir
        assert_equal ["./test", "./lib"], @config.include_paths
        assert_equal [], @config.preload_paths
        assert_equal false, @config.fail_fast
        assert_equal({ "all" => ["./test/**/*_test.rb"] }, @config.file_sets)
      end

      it "should have a validation error if the configured test directory doesn't exist" do
        @config.test_dir = "./monkey_business"

        errors = @config.validation_errors
        refute_nil errors
        assert_equal "Couldn't find test directory `./monkey_business`. Exiting.", errors[0]
      end

      it "should have a validation error if the configuration doesn't include an all file set" do
        @config.file_sets = {}

        errors = @config.validation_errors
        refute_nil errors
        assert_equal "No `all` file set is defined in your configuration. Exiting.", errors[0]
      end
    end

    a "Config with command line arguments" do
      it "should set up tracing correctly" do
        @config = Config.new(Shellwords.shellwords("--trace"))

        assert @config.trace_execution
      end

      it "should set up only running the passed command and exiting" do
        @config = Config.new(Shellwords.shellwords("--once all"))

        assert @config.once
      end

      it "should set all remaining unparsed text to be the first command to run" do
        @config = Config.new(Shellwords.shellwords("--trace set fast on"))

        assert_equal "set fast on", @config.run_command
      end
    end

    the "Config class" do
      before do
        TConsole::Config.clear_loaded_configs
      end

      it "should save the proc passed to run when it's called" do
        TConsole::Config.run do |config|
          config.test_dir = "./awesome_sauce"
        end

        assert_equal 1, TConsole::Config.instance_variable_get(:@loaded_configs).length
      end

      it "should apply the loaded configs from first to last when configure is called" do
        TConsole::Config.run do |config|
          config.test_dir = "./awesome_sauce"
        end

        TConsole::Config.run do |config|
          config.test_dir = "./awesomer_sauce"
        end

        config = TConsole::Config.configure

        assert_equal "./awesomer_sauce", config.test_dir
      end

      it "should load a config file when load_config is called" do
        TConsole::Config.load_config(File.join(File.dirname(__FILE__), "sample_config"))

        assert_equal 1, TConsole::Config.instance_variable_get(:@loaded_configs).length
      end
    end
  end
end
