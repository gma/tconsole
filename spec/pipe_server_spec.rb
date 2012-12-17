require "spec_helper"

describe TConsole::PipeServer do
  before do
    @ps = TConsole::PipeServer.new
  end

  it "can send and respond to messages" do
    test_message = "This is a test"
    fork do
      @ps.callee!

      message = @ps.read
      @ps.write(message)
    end

    @ps.caller!
    @ps.write(test_message)
    response = @ps.read

    expect(response).to eq(test_message)
  end
end


