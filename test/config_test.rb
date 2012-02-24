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
  end
end
