require 'test_helper'

module TConsole
  class ConfigTest < MiniTest::Unit::TestCase

    a "Config" do
      setup do
        @config = TConsole::Config.new
      end

      it "should have appropriate defaults" do
        assert_equal false, @config.trace_execution
        assert_equal "./test", @config.test_dir
        assert_equal ["./test", "./lib"], @config.include_paths
        assert_equal [], @config.preload_paths
        assert_equal false, @config.fail_fast
        assert_equal({ "all" => ["./test/**/*_test.rb"] }, @config.file_sets)
      end
    end

    the "Config class" do
      setup do
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
