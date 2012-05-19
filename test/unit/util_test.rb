require 'test_helper'

module TConsole
  class ConfigTest < MiniTest::Unit::TestCase
    a "Backtrace" do
      before do
        @non_tconsole_path = "/Users/alan/Projects/commondream/tconsole-test/test/functional/posts_controller_test.rb:16:in `block in <class:PostsControllerTest>'"
        @tconsole_path = "#{File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))}/posts_controller_test.rb:16:in `block in <class:PostsControllerTest>'"

        @backtrace = [
          @non_tconsole_path,
          @tconsole_path
        ]

        @filtered_backtrace = Util.filter_backtrace(@backtrace)
      end

      it "should remove the tconsole path" do
        assert_equal 1, @filtered_backtrace.length
        assert !@filtered_backtrace.include?(@tconsole_path), "Should filter backtrace item under tconsole"
      end

      it "shouldn't remove the non-tconsole path" do
        assert @filtered_backtrace.include?(@non_tconsole_path), "Should not filter backtrace item outside of tconsole"
      end

    end
  end
end
