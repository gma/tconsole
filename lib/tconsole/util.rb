module TConsole
  class Util
    # Returns [width, height] of terminal when detected, nil if not detected.
    # Think of this as a simpler version of Highline's Highline::SystemExtensions.terminal_size()
    #
    # This is a copy of HIRB's terminal size detection code: https://github.com/cldwalker/hirb/blob/master/lib/hirb/util.rb
    def self.detect_terminal_size
      if (ENV['COLUMNS'] =~ /^\d+$/) && (ENV['LINES'] =~ /^\d+$/)
        [ENV['COLUMNS'].to_i, ENV['LINES'].to_i]
      elsif (RUBY_PLATFORM =~ /java/ || (!STDIN.tty? && ENV['TERM'])) && command_exists?('tput')
        [`tput cols`.to_i, `tput lines`.to_i]
      elsif STDIN.tty? && command_exists?('stty')
        `stty size`.scan(/\d+/).map { |s| s.to_i }.reverse
      else
        nil
      end
    rescue
      nil
    end

    # Public: Filters a backtrace to exclude things that happened in TConsole
    #
    # backtrace: The backtrace array that we're filtering.
    #
    # Returns the updated backtrace.
    def self.filter_backtrace(backtrace)
      tconsole_path = File.expand_path(File.join(File.dirname(__FILE__), "..", "..")) + File::SEPARATOR
      backtrace.select do |item|
        !item.start_with?(tconsole_path)
      end
    end
  end
end
