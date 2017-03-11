# frozen_string_literal: true
require 'spec_helper'

module Enumerators
  describe BufferedEnumerator do
    let(:buffered_enumerator) { BufferedEnumerator.new(input.each) }
    let(:input) { [1, 2, 3, 4] }

    it 'yields each input element to enumerator' do
      expect(buffered_enumerator.enumerator.each.to_a).to eq input
    end

    it 'buffers the input elements' do
      expect(buffered_enumerator.buffer).to be_empty

      buffer_states = Array.new(4) do
        buffered_enumerator.enumerator.next
        buffered_enumerator.buffer.dup
      end

      expect(buffer_states).to eq [
        [1],
        [1, 2],
        [1, 2, 3],
        [1, 2, 3, 4],
      ]

      expect { buffered_enumerator.enumerator.next }.to raise_error(StopIteration)
    end

    it '' do
      2.times { buffered_enumerator.enumerator.next }
      buffered_enumerator.buffer.slice!(0, 2)
      2.times { buffered_enumerator.enumerator.next }

      expect(buffered_enumerator.buffer).to eq [3, 4]
    end
  end
end
