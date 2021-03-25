# encoding:utf-8

require 'spec_helper'

describe CelluloidPubsub::BaseActor do
  let(:actor) { TestActor.new }
  subject { actor.own_self }

  it 'returns the self' do
    expect(actor.own_self.class.name).to eq('TestActor')
    expect(actor.own_self).to_not respond_to(:mailbox)
  end

  it 'returns the actor' do
    expect(actor.cell_actor).to respond_to(:mailbox)
  end

  it 'returns true if action subscribe' do
    expect(subject.send(:action_subscribe?, 'subscribe')).to eq(true)
  end

  describe '#parse_options' do
    it 'returns empty hash for null value' do
      expect(subject.send(:parse_options, nil)).to eq({})
    end
    it 'returns empty hash for null value' do
      expect(subject.send(:parse_options, [{ a: 1 }, { b: 2 }])).to eq('b' => 2)
    end
  end

  describe 'booting up' do
    it 'does not boot if already running' do
      allow(Celluloid).to receive(:running?).and_return(true)
      expect(Celluloid).to_not receive(:boot)
      CelluloidPubsub::BaseActor.boot_up
    end

    it 'boos if not running' do
      allow(Celluloid).to receive(:running?).and_return(false)
      expect(Celluloid).to receive(:boot)
      CelluloidPubsub::BaseActor.boot_up
    end

    it 'boos if running? returns error ' do
      allow(Celluloid).to receive(:running?).and_raise(RuntimeError)
      expect(Celluloid).to receive(:boot)
      begin
        CelluloidPubsub::BaseActor.boot_up
      rescue RuntimeError => e
      end
    end
  end

  describe 'fetch_gem_version' do
    let(:gem_name) { 'rails' }
    let(:version) { '1.2.3' }

    it 'returns the loaded gem version' do
      expect(subject).to receive(:find_loaded_gem_property).with(gem_name).and_return(nil)
      result = actor.send(:fetch_gem_version, gem_name)
      expect(result).to eq(nil)
    end

    it 'returns the loaded gem version' do
      expected = 1.2
      expect(subject).to receive(:find_loaded_gem_property).with(gem_name).and_return(version)
      expect(subject).to receive(:get_parsed_version).with(version).and_return(expected)
      result = actor.send(:fetch_gem_version, gem_name)
      expect(result).to eq(expected)
    end
  end
  describe 'filtered_error?' do
    it 'filters the interrupt exception' do
      error = Interrupt.new
      expect(actor.send(:filtered_error?, error)).to eq(true)
    end
  end
end
