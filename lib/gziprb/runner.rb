# frozen_string_literal: true
module Runner
  class << self
    def assert_correct_invocation_and_get_args
      if ARGV.size > 1 || ARGV.include?('--help')
        STDERR.puts("Usage: #{$PROGRAM_NAME} [input_file]")
        exit(1)
      end

      first_arg = ARGV[0]

      if first_arg.nil?
        ['-', STDIN]
      else
        [first_arg, File.open(first_arg, 'r')]
      end
    end
  end
end
