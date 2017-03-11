# frozen_string_literal: true
# This class is a (append-only) ring buffer using an undlerying fixed-size array used to store a
# window of "recently"-seen input elements.
class OverwritingRingBuffer
  class BufferFullError < StandardError; end

  attr_reader :max_size

  attr_reader :size
  alias length size

  def initialize(max_size)
    @buffer = Array.new(max_size)
    @size = 0
    @max_size = max_size
    @read_index = 0
  end

  def <<(elem)
    @buffer[wrap(@read_index + @size)] = elem

    if full?
      increment_read_index
    else
      @size += 1
    end
  end

  def concat(elems)
    elems.each { |elem| self.<< elem }
  end

  def [](index)
    @buffer[resolve_index(index)]
  end

  def to_a
    (0...@size).map do |i|
      self.[](i)
    end
  end

  def full?
    @size == max_size
  end

  def empty?
    @size.zero?
  end

  def drop!(count)
    return [] if count < 1

    @size -= count

    Array.new(count) do
      @buffer[@read_index].tap { increment_read_index }
    end
  end

  def take(count)
    return [] if count < 1

    (0...count).map { |i| self.[](i) }
  end

  def last(count)
    start_index = wrap(@read_index + (@size - count))

    (0...count).map do |i|
      @buffer[wrap(start_index + i)]
    end
  end

  private

  def resolve_index(index)
    index += @size if index.negative?
    wrap(@read_index + index)
  end

  def wrap(val)
    val % @max_size
  end

  def increment_read_index
    @read_index = wrap(@read_index + 1)
  end
end
