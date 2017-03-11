# frozen_string_literal: true
require 'spec_helper'

describe OverwritingRingBuffer do
  let(:buffer) { OverwritingRingBuffer.new(3) }

  describe '#max_size' do
    it { expect(OverwritingRingBuffer.new(10).max_size).to eq 10 }
    it { expect(OverwritingRingBuffer.new(1).max_size).to eq 1 }
  end

  it 'correctly wraps-around' do
    expect(buffer.to_a).to eq []
    buffer << :a
    expect(buffer.to_a).to eq %i(a)
    buffer << :b
    expect(buffer.to_a).to eq %i(a b)
    buffer << :c
    expect(buffer.to_a).to eq %i(a b c)
    buffer << :d
    expect(buffer.to_a).to eq %i(b c d)
    buffer << :e
    expect(buffer.to_a).to eq %i(c d e)
    buffer << :f
    expect(buffer.to_a).to eq %i(d e f)
  end

  describe '#<<' do
    it 'stores elements in FIFO order' do
      buffer << :a
      buffer << :b
      buffer << :c

      expect(buffer.to_a).to eq %i(a b c)
    end

    it 'drops first element when inserting a new element when it is full' do
      buffer << :a
      buffer << :b
      buffer << :c
      buffer << :d

      expect(buffer.to_a).to eq %i(b c d)
    end
  end

  describe '#drop' do
    it 'drops and returns a single element' do
      buffer << :a
      expect(buffer.drop!(1)).to eq %i(a)
      expect(buffer).to be_empty
      expect(buffer.size).to eq 0
    end

    it 'drops multiple elements' do
      buffer.concat(%i(a b c))
      expect(buffer.drop!(2)).to eq %i(a b)
      expect(buffer.to_a).to eq %i(c)
      expect(buffer.size).to eq 1
    end

    it 'works with multiple calls' do
      buffer.concat(%i(a b c))
      expect(buffer.drop!(2)).to eq %i(a b)
      buffer.concat(%i(d e))
      expect(buffer.drop!(2)).to eq %i(c d)
      buffer << :f
      expect(buffer.drop!(2)).to eq %i(e f)
      expect(buffer).to be_empty
      expect(buffer.size).to eq 0
    end
  end

  describe '#take' do
    it 'returns a single element' do
      buffer << :a
      expect(buffer.take(1)).to eq %i(a)
    end

    it 'takes multiple elements' do
      buffer.concat(%i(a b c))
      expect(buffer.take(1)).to eq %i(a)
      expect(buffer.take(2)).to eq %i(a b)
      expect(buffer.take(3)).to eq %i(a b c)
    end

    it 'works with multiple calls' do
      buffer.concat(%i(a b c))
      expect(buffer.take(2)).to eq %i(a b)
      buffer.concat(%i(d e f))
      expect(buffer.take(2)).to eq %i(d e)
    end
  end

  describe '#concat' do
    it 'can correctly insert multiple elements' do
      buffer.concat(%i(c d e))

      expect(buffer.to_a).to eq %i(c d e)
    end

    it 'works with wrap-around' do
      buffer.concat(%i(a b c))
      buffer.concat(%i(d e f))
      buffer.concat(%i(g h))

      expect(buffer.to_a).to eq %i(f g h)
    end
  end

  describe '#[]' do
    context 'with a single element' do
      it 'is correct' do
        buffer << :a

        expect(buffer[0]).to eq :a
        expect(buffer[-1]).to eq :a
      end
    end

    context 'with multiple elements' do
      def expect_chars_at_indices(char_indices)
        char_indices.each do |c, indices|
          indices.each do |i|
            expect(buffer[i]).to eq c
          end
        end
      end

      context 'when not full' do
        before(:each) { buffer.concat(%i(a b)) }

        it { expect_chars_at_indices(a: [0, -2], b: [1, -1]) }
      end

      context 'when full' do
        before(:each) { buffer.concat(%i(a b c)) }

        context 'without wrap-around' do
          it { expect_chars_at_indices(a: [0, -3], b: [1, -2], c: [2, -1]) }
        end

        context 'without wrap-around' do
          before(:each) { buffer.concat(%i(d e)) }

          it { expect_chars_at_indices(c: [0, -3], d: [1, -2], e: [2, -1]) }
        end
      end
    end
  end

  describe '#full?' do
    it 'is false until the buffer is full' do
      expect(buffer).to_not be_full
      buffer << :a
      expect(buffer).to_not be_full
      buffer << :b
      expect(buffer).to_not be_full
      buffer << :c
      expect(buffer).to be_full
    end
  end

  describe '#empty?' do
    it 'is false unless the buffer is empty' do
      expect(buffer).to be_empty
      buffer << :a
      expect(buffer).to_not be_empty
      buffer << :b
      expect(buffer).to_not be_empty
      buffer << :c
      expect(buffer).to_not be_empty
    end
  end

  describe '#last' do
    it 'returns a single element' do
      buffer << :a
      expect(buffer.last(1)).to eq %i(a)
    end

    it 'returns multiple elements' do
      buffer.concat(%i(a b c))
      expect(buffer.last(1)).to eq %i(c)
      expect(buffer.last(2)).to eq %i(b c)
      expect(buffer.last(3)).to eq %i(a b c)
    end
  end
end
