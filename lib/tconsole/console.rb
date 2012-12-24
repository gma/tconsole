module TConsole
  class Console
    KNOWN_COMMANDS = ["exit", "reload", "help", "info", "!failed", "!timings", "set"]

    attr_accessor :config, :reporter

    def initialize(config, reporter)
      self.config = config
      self.reporter = reporter
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
    def read_and_execute(pipe_server)
      prompt = "tconsole> "

      trap("SIGTSTP", "SYSTEM_DEFAULT")
      trap("SIGCONT") do
        print prompt
      end

      # Run any commands that have been passed
      result = process_command(pipe_server, @config.run_command)
      @config.run_command = ""
      if result == :exit || @config.once
        return false
      elsif result == :reload
        return true
      end

      # The command entry loop
      while command = Readline.readline(prompt, false)
        command.strip!
        result = process_command(pipe_server, command)

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
    # pipe_server - The pipe server we're working with
    # command - The command we need to parse and handle
    def process_command(pipe_server, command)
      args = Shellwords.shellwords(command)

      # save the command unless we're exiting or repeating the last command
      unless args[0] == "exit" || (Readline::HISTORY.length > 0 && Readline::HISTORY[Readline::HISTORY.length - 1] == command)
        Readline::HISTORY << command
      end

      if command == ""
        # do nothing
      elsif args[0] == "exit"
        send_message(pipe_server, :stop)
        return :exit
      elsif args[0] == "reload"
        send_message(pipe_server, :stop)
        return :reload
      elsif args[0] == "help"
        reporter.help_message
      elsif args[0] == "!failed"
        send_message(pipe_server, :run_failed)
      elsif args[0] == "!timings"
        send_message(pipe_server, :show_performance, args[1])
      elsif args[0] == "info"
        send_message(pipe_server, :run_info)
      elsif args[0] == "set"
        send_message(pipe_server, :set, args[1], args[2])
      elsif args[0].start_with?(".")
        shell_command(command[1, command.length - 1])
      elsif @config.file_sets.has_key?(args[0])
        send_message(pipe_server, :run_file_set, args[0])
      else
        send_message(pipe_server, :run_all_tests, args)
      end

      nil
    end

    def send_message(pipe_server, message, *args)
      pipe_server.write({:action => message.to_sym, :args => args})
      pipe_server.read
    end

    # Internal: Runs a shell command on the console and outputs the results.
    def shell_command(command)
      system(command)

      result = $?

      reporter.info
      if result.exitstatus == 0
        reporter.exclaim("Command exited with status code: 0")
      else
        reporter.error("Command exited with status code: #{result.exitstatus}")
      end
    end

    def history_file
      File.join(ENV['HOME'], ".tconsole_history")
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
