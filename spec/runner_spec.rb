require "spec_helper"

describe TConsole::Runner do
  before do
    @runner = TConsole::Runner.new(:minitest)
    @ps = ChattyProc::PipeServer.new
  end

  describe "#load_environment" do
    before do
      @ps.stub(:write) { }
    end

    it "returns false if the environment load call fails" do
      @ps.stub(:read) { false }
      expect(@runner.load_environment(@ps)).to be_false
    end

    it "returns true if the environment load call succeeds" do
      @ps.stub(:read) { true }
      expect(@runner.load_environment(@ps)).to be_true
    end
  end

  describe "#console_run_loop" do
    before do
      @config = TConsole::Config.new(:minitest)
      @reporter = TConsole::Reporter.new(@config)
      @console = TConsole::Console.new(@config, @reporter)
    end

    it "returns false when loading the environment fails" do
      @runner.stub(:load_environment) { false }

      expect(@runner.console_run_loop(@console)).to be_false
    end
  end
end
