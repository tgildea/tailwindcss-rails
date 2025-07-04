namespace :tailwindcss do
  desc "Build your Tailwind CSS"
  task build: [:environment, :engines] do |_, args|
    debug = args.extras.include?("debug")
    verbose = args.extras.include?("verbose")

    Tailwindcss::Commands.input_output_mappings.each do |input, output|
      command = Tailwindcss::Commands.compile_command(input:, output:, debug: debug)
      env = Tailwindcss::Commands.command_env(verbose: verbose)
      puts "Running: #{Shellwords.join(command)}" if verbose

      system(env, *command, exception: true)
    end
  end

  desc "Watch and build your Tailwind CSS on file changes"
  task watch: [:environment, :engines] do |_, args|
    debug = args.extras.include?("debug")
    poll = args.extras.include?("poll")
    always = args.extras.include?("always")
    verbose = args.extras.include?("verbose")

    tailwind_pids = []

    # Define cleanup method
    cleanup = -> do
      puts "Stopping #{tailwind_pids.count} tailwind processes..." if verbose
      tailwind_pids.each do |pid|
        begin
          Process.kill(:INT, pid)
          Process.wait(pid)
        rescue Errno::ECHILD, Errno::ESRCH
          # Process may already be gone
        end
      end
    end

    # Set up signal handlers
    Signal.trap("INT") { cleanup.call; exit(0) }
    Signal.trap("TERM") { cleanup.call; exit(0) }

    begin
      Tailwindcss::Commands.input_output_mappings.each do |input, output|
        tailwind_pids << fork do
          command = Tailwindcss::Commands.watch_command(input:, output:, always: always, debug: debug, poll: poll)
          env = Tailwindcss::Commands.command_env(verbose: verbose)
          puts "Running: #{Shellwords.join(command)}" if verbose

          system(env, *command)
        end
      end

      # Monitor child processes
      loop do
        tailwind_pids.each do |pid|
          begin
            if Process.waitpid(pid, Process::WNOHANG)
              puts "Tailwind process #{pid} exited unexpectedly" if verbose
              cleanup.call
              exit(1)
            end
          rescue Errno::ECHILD
            # Process is already gone
            puts "Tailwind process #{pid} is no longer running" if verbose
            cleanup.call
            exit(1)
          end
        end
        sleep 2
      end
    ensure
      cleanup.call
    end
  end

  desc "Create Tailwind CSS entry point files for Rails Engines"
  task engines: :environment do
    Tailwindcss::Engines.bundle
  end
end

Rake::Task["assets:precompile"].enhance(["tailwindcss:build"])

if Rake::Task.task_defined?("test:prepare")
  Rake::Task["test:prepare"].enhance(["tailwindcss:build"])
elsif Rake::Task.task_defined?("spec:prepare")
  Rake::Task["spec:prepare"].enhance(["tailwindcss:build"])
elsif Rake::Task.task_defined?("db:test:prepare")
  Rake::Task["db:test:prepare"].enhance(["tailwindcss:build"])
end
