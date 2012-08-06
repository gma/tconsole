module TConsole
  class Console
    KNOWN_COMMANDS = ["exit", "reload", "help", "info", "!failed", "!timings", "set"]

    attr_accessor :pipe_server

    def initialize(config)
      @config = config
      read_history

      define_autocomplete
    end

    def define_autocomplete
      Readline.completion_append_character = ""

      # Proc for helping us figure out autocompletes
      Readline.completion_proc = Proc.new do |str|
        known_commands = KNOWN_COMMANDS.grep(/^#{Regexp.escape(str)}/)
        known_commands.concat(@config.file_sets.keys.grep(/^#{Regexp.escape(str)}/))

        known_elements = []
        unless pipe_server.nil?
          known_elements = send_message(:autocomplete, str)
        end

        known_commands.concat(known_elements)
      end
    end

    # Returns true if the app should keep running, false otherwise
    def read_and_execute
      if pipe_server.nil?
        puts "No connection to test environment. Exiting."
        return false
      end

      prompt = "tconsole> "

      trap("SIGTSTP", "SYSTEM_DEFAULT")
      trap("SIGCONT") do
        print prompt
      end

      # Run any commands that have been passed
      result = process_command(@config.run_command)
      @config.run_command = ""
      if result == :exit || @config.once
        return false
      elsif result == :reload
        return true
      end

      # The command entry loop
      while command = Readline.readline(prompt, false)
        command.strip!
        result = process_command(command)

        if result == :exit
          return false
        elsif result == :reload
          return true
        end
      end

      send_message(:stop)
      false
    end

    # Public: Process a command however it needs to be handled.
    #
    # command - The command we need to parse and handle
    def process_command(command)
      args = Shellwords.shellwords(command)

      # save the command unless we're exiting or repeating the last command
      unless args[0] == "exit" || last_command == command
        Readline::HISTORY << command
      end

     if command == ""
        # do nothing
      elsif args[0] == "exit"
        send_message(:stop)
        self.pipe_server = nil
        return :exit
      elsif args[0] == "reload"
        send_message(:stop)
        return :reload
      elsif args[0] == "help"
        print_help
      elsif args[0] == "!failed"
        send_message(:run_failed)
      elsif args[0] == "!timings"
        send_message(:show_performance, args[1])
      elsif args[0] == "info"
        send_message(:run_info)
      elsif args[0] == "set"
        send_message(:set, args[1], args[2])
      elsif @config.file_sets.has_key?(args[0])
        send_message(:run_file_set, args[0])
      else
        send_message(:run_all_tests, args)
      end

      nil
    end

    def send_message(message, *args)
      pipe_server.write({:action => message.to_sym, :args => args})
      pipe_server.read
    end

    # Prints a list of available commands
    def print_help
      puts
      puts "Available commands:"
      puts
      puts "reload                      # Reload your Rails environment"
      puts "set [variable] [value]      # Sets a runtime variable (see below for details)"
      puts "exit                        # Exit the console"
      puts "!failed                     # Runs the last set of failing tests"
      puts "!timings [limit]            # Lists the timings for the last test run, sorted."
      puts "[filename] [test_pattern]   # Run the tests contained in the given file"
      puts
      puts "Running file sets"
      puts
      puts "File sets are sets of files that are typically run together. For example,"
      puts "in Rails projects it's common to run `rake test:units` to run all of the"
      puts "tests under the units directory."
      puts
      puts "Available file sets:"

      @config.file_sets.each do |set, paths|
        puts set
      end

      puts
      puts "Working with test patterns:"
      puts
      puts "All of the test execution commands include an optional test_pattern argument. A"
      puts "test pattern can be given to filter the executed tests to only those tests whose"
      puts "name matches the pattern given. This is especially useful when rerunning a failing"
      puts "test."
      puts
      puts "Runtime Variables"
      puts
      puts "You can set runtime variables with the set command. This helps out with changing"
      puts "features of TConsole that you may want to change at runtime. At present, the"
      puts "following runtime variables are available:"
      puts
      puts "fast        # Turns on fail fast mode. Values: on, off"
      puts

    end

    def history_file
      File.join(ENV['HOME'], ".tconsole_history")
    end

    def last_command
      return nil if Readline::HISTORY.length <= 0
      if Kernel.one_eight?
        Readline::HISTORY.to_a[Readline::HISTORY.length - 1]
      else
        Readline::HISTORY[Readline::HISTORY.length - 1]
      end
    end

    # Stores last 50 items in history to $HOME/.tconsole_history
    def store_history
      if ENV['HOME']
        File.open(history_file, "w") do |f|
          Readline::HISTORY.to_a.reverse[0..49].each do |item|
            f.puts(item)
          end
        end
      end
    end

    # Loads history from past sessions
    def read_history
      if ENV['HOME'] && File.exist?(history_file)
        File.readlines(history_file).reverse.each do |line|
          Readline::HISTORY << line
        end
      end
    end
  end
end
