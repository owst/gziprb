# frozen_string_literal: true
require 'spec_helper'

describe RunLengthEncoding do
  def expect_rle(input, expected)
    expect(RunLengthEncoding.rle(input)).to eq expected
  end

  it 'handles an empty array' do
    expect_rle([], [])
  end

  it 'handles no reptitions' do
    expect_rle([1, 2, 3], [[1, 1], [2, 1], [3, 1]])
  end

  it 'handles only reptitions' do
    expect_rle([1, 1, 1, 2, 2, 3, 3, 3], [[1, 3], [2, 2], [3, 3]])
  end

  it 'handles a mix of (non-)reptitions' do
    expect_rle([1, 1, 1, 2, 3, 3, 4, 5, 5], [[1, 3], [2, 1], [3, 2], [4, 1], [5, 2]])
  end
end
