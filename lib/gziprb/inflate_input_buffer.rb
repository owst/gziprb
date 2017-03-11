# frozen_string_literal: true
# Allows reading of individual bits (as per the Deflate spec, from the rightmost bit first) or
# whole bytes from an underlying IO, which is consumed on demand.
class InflateInputBuffer
  def initialize(io)
    @io = io
    @offset_from_lsb = :uninitialised
  end

  def eof?
    next_byte_required? && @io.eof?
  end

  def read_bit_string(n)
    # Reads the bits MSB first, and then reverse to obtain a bit string with MSB on the left
    Array.new(n) { read_bit }.reverse.join
  end

  def read_number(n)
    read_bit_string(n).to_i(2)
  end

  def read_to_end_of_current_byte
    read_bit until next_byte_required?
  end

  def read_bit
    raise 'eof!' if eof?

    next_byte if next_byte_required?

    true_bit = (@byte & (1 << @offset_from_lsb)).positive?
    @offset_from_lsb += 1

    true_bit ? 1 : 0
  end

  def read_raw_bytes(n)
    return to_enum(__method__, n) unless block_given?

    n.times do
      raise 'eof!' if eof?

      next_byte

      yield @byte

      @offset_from_lsb = 8
    end
  end

  private

  def next_byte_required?
    @byte.nil? || @offset_from_lsb == 8
  end

  def next_byte
    unless [:uninitialised, 8].include?(@offset_from_lsb)
      raise "Cannot advance byte with only #{@offset_from_lsb} bits read of current byte"
    end

    raise 'Underlying stream is at eof, cannot read next byte' if @io.eof?

    @byte = @io.read(1).unpack('C').first
    @offset_from_lsb = 0
  end
end
