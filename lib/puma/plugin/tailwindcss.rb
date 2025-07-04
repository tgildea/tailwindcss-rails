require "puma/plugin"
require "tailwindcss/commands"

Puma::Plugin.create do
  attr_reader :puma_pid, :tailwind_pids, :log_writer

  def start(launcher)
    @log_writer = launcher.log_writer
    @puma_pid = $$
    @tailwind_pids = []

    Tailwindcss::Commands.input_output_mappings.each do |input, output|
      @tailwind_pids << fork do
        Thread.new { monitor_puma }
        # Using IO.popen(command, 'r+') will avoid watch_command read from $stdin.
        # If we use system(*command) instead, IRB and Debug can't read from $stdin
        # correctly bacause some keystrokes will be taken by watch_command.
        begin
          IO.popen(Tailwindcss::Commands.watch_command(input:, output:), 'r+') do |io|
            IO.copy_stream(io, $stdout)
          end
        rescue Interrupt
        end
      end
    end

    launcher.events.on_stopped { stop_tailwind }

    in_background do
      monitor_tailwind
    end
  end

  private
    def stop_tailwind
      log "Stopping #{tailwind_pids.size} tailwind process(es)..."
      tailwind_pids.each do |pid|
        begin
          Process.waitpid(pid, Process::WNOHANG)
          Process.kill(:INT, pid)
          Process.wait(pid)
        rescue Errno::ECHILD, Errno::ESRCH
          # Process already gone
        end
      end
    end

    def monitor_puma
      monitor(:puma_dead?, "Detected Puma has gone away, stopping tailwind...")
    end

    def monitor_tailwind
      monitor(:tailwind_dead?, "Detected tailwind has gone away, stopping Puma...")
    end

    def monitor(process_dead, message)
      loop do
        if send(process_dead)
          log message
          Process.kill(:INT, $$)
          break
        end
        sleep 2
      end
    end

    def tailwind_dead?
      tailwind_pids.any? do |pid|
        begin
          Process.waitpid(pid, Process::WNOHANG)
          false
        rescue Errno::ECHILD, Errno::ESRCH
          true
        end
      end
    end

    def puma_dead?
      Process.ppid != puma_pid
    end

    def log(...)
      log_writer.log(...)
    end
end
