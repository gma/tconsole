module TConsole
  class Runner

    attr_accessor :mode, :config, :reporter, :console, :stty_save

    # Public: Sets up the new runner's config.
    def initialize(mode, argv = [])
      self.mode = mode
      
      # try to load the default configs
      Config.load_config(File.join(Dir.home, ".tconsole"))
      Config.load_config(File.join(Dir.pwd, ".tconsole"))
      self.config = Config.configure(argv)
      self.reporter = Reporter.new(config)
    end

    # Spawns a new environment. Looks at the results of the environment to determine 
    # whether to stop or keep running
    def run
      prepare_process
      reporter.welcome_message
      exit(1) if print_config_errors

      # Set up our console input handling and history
      console = Console.new(config, reporter)

      # Start the server
      while console_run_loop(console)
        # just need to run the loop
      end

      console.store_history

      cleanup_process
    end

    # Internal: Set up the process and console.
    def prepare_process
      self.stty_save = `stty -g`.chomp

      trap("SIGINT", "IGNORE")
      trap("SIGTSTP", "IGNORE")
    end

    # Internal: Cleans up the process at the end of execution.
    def cleanup_process
      reporter.exit_message
      system("stty", self.stty_save);
    end

    # Internal: Prints config errors, if there are any.
    #
    # Returns true if there were errors, false otherwise.
    def print_config_errors
      config_errors = @config.validation_errors
      if config_errors.length > 0
        reporter.error
        reporter.error(config_errors.first)
        true
      else
        false
      end
    end

    # Internal: Environment reload run loop.
    #
    # This run loop handles spawning a new tconsole environment - it's basically
    # just there to handle reloads. Also calls out to the input loop for the
    # console.
    #
    # Returns false if tconsole needs to stop, true otherwise.
    def console_run_loop(console)
      pipe_server = ChattyProc::PipeServer.new

      reporter.trace("Forking test server.")
      server_pid = fork do
        server_run_loop(pipe_server)
      end

      pipe_server.caller!
      unless load_environment(pipe_server)
        pipe_server.write({:action => "exit"})
        return false
      end

      continue = console.read_and_execute(pipe_server)
      reporter.trace("Console read loop returned - continue: #{continue}")

      Process.waitall

      continue
    end

    # Internal: Asks the server to load the environment.
    #
    # Returns true if the environment was loaded, or false otherwise.
    def load_environment(pipe_server)
      reporter.trace("Attempting to load environment.")
      pipe_server.write({:action => "load_environment"})

      if pipe_server.read
        reporter.trace("Environment loaded successfully.")
        true
      else
        reporter.error("Couldn't load the test environment. Exiting.")
        false
      end
    end

    # Internal: Run loop for the server.
    def server_run_loop(pipe_server)
      pipe_server.callee!
      
      if mode == :minitest
        server = MinitestServer.new(config, reporter)
      elsif mode == :rspec
        server = RspecServer.new(config, reporter)
      else
        reporter.error
        reporter.error("The given test mode isn't supported.")
        reporter.error
        exit
      end

      while message = pipe_server.read
        reporter.trace("Server Received Message: #{message[:action]}")
        begin
          result = server.handle(message)
          pipe_server.write(result)
        rescue => e
          reporter.error
          reporter.error("An error occured: #{e.message}")
          reporter.trace_backtrace(e)
          pipe_server.write(nil)
        end
      end
    end
  end
end
