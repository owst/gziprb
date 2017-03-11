# frozen_string_literal: true
module Enumerators
  class BufferedEnumerator
    attr_reader :buffer
    attr_reader :enumerator

    def initialize(input)
      @buffer = []

      @enumerator = Enumerator.new do |enum|
        input.each do |byte|
          @buffer << byte
          enum << byte
        end
      end
    end
  end
end
