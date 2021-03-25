# encoding:utf-8

require 'spec_helper'

describe CelluloidPubsub::Registry do
  before(:each) do
    CelluloidPubsub::Registry.channels = []
    CelluloidPubsub::Registry.messages = {}
  end

  it 'has class attribute channels' do
    act = CelluloidPubsub::Registry.respond_to?(:channels)
    expect(act).to eq true
  end

  it 'defaults to empty array for channels' do
    expect(CelluloidPubsub::Registry.channels).to eq([])
  end

  it 'has class attribute messages' do
    act = CelluloidPubsub::Registry.respond_to?(:messages)
    expect(act).to eq true
  end

  it 'defaults to empty hash for messages' do
    expect(CelluloidPubsub::Registry.messages).to eq({})
  end
end
