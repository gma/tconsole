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
    encoded_message = [Marshal.dump(message)].pack("m")
    @me[1].puts(encoded_message)
  end

  # Reads a message from the appropriate pipe and unmarshalls it
  def read
    raw_message = @me[0].gets

    return nil if raw_message.nil?

    Marshal.load(raw_message.unpack("m")[0])
  end
end

server = PipeServer.new

server_pid = fork do
  server.callee!

  while message = server.read
    puts "SERVER READ message: #{message}"

    if message == "exit"
      puts "SERVER EXITING"
      exit(0)
    else
      server.write("ECHO: #{message}")
    end
  end
end

server.caller!

10.times do
  time = Time.now.to_s

  puts "CLIENT SEND: #{time}"
  server.write(time)

  # Wait for the response
  message = server.read

  puts "CLIENT RECEIVED: #{message}"

  sleep(1)
end

server.write("exit")

Process.wait(server_pid)

puts "All done!"


