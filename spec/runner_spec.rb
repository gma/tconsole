require "spec_helper"

describe TConsole::Runner do
  before do
    @runner = TConsole::Runner.new
    @ps = TConsole::PipeServer.new
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
end
