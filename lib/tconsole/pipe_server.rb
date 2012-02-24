module TConsole
  class PipeServer

    def initialize
      @callee = []
      @caller = []
      @callee[0], @caller[1] = IO.pipe
      @caller[0], @callee[1] = IO.pipe

      @me = nil
    end

    # Identifies the current process as the callee process
    def callee!
      @me = @callee

      @caller.each do |io|
        io.close
      end
    end

    # Identifies the current process as the caller process
    def caller!
      @me = @caller

      @callee.each do |io|
        io.close
      end
    end

    # Writes a message to the appropriate pipe. The message can be
    # anything that will Marshal cleanly
    def write(message)
      encoded_message = [Marshal.dump(message)].pack("m0")
      @me[1].puts(encoded_message)
    end

    # Reads a message from the appropriate pipe and unmarshalls it
    def read
      raw_message = @me[0].gets

      return nil if raw_message.nil?

      Marshal.load(raw_message.unpack("m")[0])
    end
  end
end
