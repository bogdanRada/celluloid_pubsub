# encoding:utf-8

require 'spec_helper'

describe CelluloidPubsub::Registry do
  it 'has class atributes' do
    act = CelluloidPubsub::Registry.respond_to?(:channels)
    act.should eq true
  end
end
