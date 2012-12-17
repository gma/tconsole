require 'spec_helper'

describe "TConsole::Util" do
  describe ".filter_backtrace" do
    before do
      @non_tconsole_path = "/Users/alan/Projects/commondream/tconsole-test/test/functional/posts_controller_test.rb:16:in `block in <class:PostsControllerTest>'"
      @tconsole_path = "#{File.expand_path(File.join(File.dirname(__FILE__), ".."))}/posts_controller_test.rb:16:in `block in <class:PostsControllerTest>'"

      @backtrace = [
        @non_tconsole_path,
        @tconsole_path
      ]

      @filtered_backtrace = TConsole::Util.filter_backtrace(@backtrace)
    end

    context "removes tconsole paths" do
      it { expect(@filtered_backtrace.length).to eq(1) }
      it { expect(@filtered_backtrace).to_not include(@tconsole_path) }
    end

    it "doesn't remove non-tconsole paths" do
      expect(@filtered_backtrace).to include(@non_tconsole_path)
    end
  end
end
