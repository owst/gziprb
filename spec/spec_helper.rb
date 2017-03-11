# frozen_string_literal: true
require 'gziprb'
require 'stringio'

def read_fixture(name)
  File.read(File.join(__dir__, 'fixtures', name))
end

def random_bytearray(random, size)
  seen = Set.new
  probability_of_new_character = 1 / 75.0

  Array.new(size) do
    if random.rand > probability_of_new_character && !seen.empty?
      seen.to_a[random.rand(seen.size)]
    else
      random.bytes(1).tap { |byte| seen << byte }
    end
  end
end

RSpec.configure do |c|
  c.example_status_persistence_file_path = 'spec_examples.txt'
end
