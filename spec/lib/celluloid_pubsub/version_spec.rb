# encoding:utf-8

require 'spec_helper'

describe CelluloidPubsub do
  it 'returns the string' do
    expected = [
      CelluloidPubsub::VERSION::MAJOR,
      CelluloidPubsub::VERSION::MINOR,
      CelluloidPubsub::VERSION::TINY,
      CelluloidPubsub::VERSION::PRE
    ].compact.join('.')
    expect(CelluloidPubsub::VERSION::STRING).to eq(expected)
  end

  it 'returns the gem version' do
    expected = 'something'
    expect(::Gem::Version).to receive(:new).with(CelluloidPubsub::VERSION::STRING).and_return(expected)
    expect(CelluloidPubsub.gem_version).to eq(expected)
  end
end
