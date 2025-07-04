require "tailwindcss/ruby"

module Tailwindcss
  module Commands
    class << self
      def compile_command(input: "application.css", output: "tailwind.css", debug: false, **kwargs)
        debug = ENV["TAILWINDCSS_DEBUG"].present? if ENV.key?("TAILWINDCSS_DEBUG")

        command = [
          Tailwindcss::Ruby.executable(**kwargs),
          "-i", input_path.join(input).to_s,
          "-o", output_path.join(output).to_s,
        ]

        command << "--minify" unless (debug || rails_css_compressor?)

        postcss_path = rails_root.join("postcss.config.js")
        command += ["--postcss", postcss_path.to_s] if File.exist?(postcss_path)

        command
      end

      def watch_command(always: false, poll: false, **kwargs)
        compile_command(**kwargs).tap do |command|
          command << "-w"
          command << "always" if always
          command << "-p" if poll
        end
      end

      def command_env(verbose:)
        {}.tap do |env|
          env["DEBUG"] = "1" if verbose
        end
      end

      def rails_css_compressor?
        defined?(Rails) && Rails&.application&.config&.assets&.css_compressor.present?
      end

      def rails_root
        defined?(Rails) ? Rails.root : Pathname.new(Dir.pwd)
      end

      def input_path
        Pathname.new(rails_root.join("app", "assets", "tailwind"))
      end

      def output_path
        Pathname.new(rails_root.join("app", "assets", "builds"))
      end

      def input_files
        Dir.glob(input_path.join("*.css"))
      end

      def input_output_mappings
        input_files.map do |input_file|
          [ input_file, "tailwind-#{File.basename(input_file)}" ]
        end
      end
    end
  end
end
