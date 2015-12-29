# encoding:utf-8

require 'spec_helper'

describe CelluloidPubsub::Client do
  let(:blk) { proc { |a| puts a } }
  let(:options) { {} }
  let(:actor) { mock }
  let(:connection) { mock }
  let(:channel) { 'some_channel' }

  before(:each) do
    CelluloidPubsub::Client.any_instance.stubs(:supervise_actors).returns(true)
    CelluloidPubsub::Client.any_instance.stubs(:connection).returns(connection)
    @worker = CelluloidPubsub::Client.new(actor: actor, channel: channel, enable_debug: false)
    @worker.stubs(:debug).returns(true)
    @worker.stubs(:async).returns(@worker)
    actor.stubs(:async).returns(actor)
    actor.stubs(:respond_to?).returns(false)
    actor.stubs(:terminate).returns(true)
    connection.stubs(:terminate).returns(true)
    connection.stubs(:text).returns(true)
  end

  describe '#initialize' do
    it 'creates a object' do
      expect(@worker.channel).to eq channel
      expect(@worker.actor).to eq actor
    end
  end

  # describe '#parse_options' do
  #   let(:actor) { mock }
  #   let(:hostname) { '127.0.0.1' }
  #   let(:port) { 9999 }
  #   let(:path) { '/some_path' }
  #   let(:custom_options) { { actor: actor, hostname: hostname, port: port, path: path } }
  #
  #   it 'parses options' do
  #     @worker.parse_options(custom_options)
  #     expect(@worker.actor).to eq(actor)
  #     expect(@worker.hostname).to eq(hostname)
  #     expect(@worker.port).to eq(port)
  #     expect(@worker.path).to eq(path)
  #   end
  #
  #   it 'sets defaults' do
  #     @worker.parse_options({})
  #     expect(@worker.actor).to eq(nil)
  #     expect(@worker.hostname).to eq('0.0.0.0')
  #     expect(@worker.port).to eq(1234)
  #     expect(@worker.path).to eq('/ws')
  #   end
  # end

  describe '#debug_enabled?' do
    it 'checks if debug is enabled' do
      act = @worker.debug_enabled?
      expect(act).to eq(false)
    end
  end

  describe '#subscribe' do
    let(:channel) { 'some_channel' }
    it 'chats with the server' do
      @worker.expects(:chat).with('client_action' => 'subscribe', 'channel' => channel)
      @worker.subscribe(channel)
    end
  end

  describe '#succesfull_subscription?' do
    let(:message) { mock }
    let(:action) { mock }

    before(:each) do
      message.stubs(:present?).returns(true)
      message.stubs(:[]).with('client_action').returns('successful_subscription')
    end

    it 'checks the message and returns true' do
      message.expects(:is_a?).with(Hash).returns(true)
      message.stubs(:[]).with('client_action').returns('successful_subscription')
      actual = @worker.succesfull_subscription?(message)
      expect(actual).to eq(true)
    end

    it 'checks the message and returns false' do
      message.expects(:is_a?).with(Hash).returns(true)
      message.stubs(:[]).with('client_action').returns('something_else')
      actual = @worker.succesfull_subscription?(message)
      expect(actual).to eq(false)
    end
  end

  describe '#publish' do
    let(:channel) { 'some_channel' }
    let(:data) { 'some_message' }
    it 'chats with the server' do
      @worker.expects(:send_action).with('publish', channel, data)
      @worker.publish(channel, data)
    end
  end

  describe '#on_open' do
    let(:channel) { 'some_channel' }
    let(:data) { 'some_message' }
    it 'chats with the server' do
      @worker.expects(:subscribe).with(channel)
      @worker.on_open
    end
  end

  describe '#on_message' do
    let(:channel) { 'some_channel' }
    let(:data) { 'some_message' }
    it 'chats with the server' do
      JSON.expects(:parse).with(data).returns(data)
      @worker.actor.expects(:async).returns(actor)
      @worker.actor.expects(:on_message).with(data)
      @worker.on_message(data)
    end
  end

  describe '#on_close' do
    let(:channel) { 'some_channel' }
    let(:code) { 'some_code' }
    let(:reason) { 'some_reason' }

    it 'chats with the server' do
      actor.expects(:on_close).with(code, reason).returns(true)
      @worker.on_close(code, reason)
    end
  end

  describe '#chat' do
    let(:channel) { 'some_channel' }
    let(:data) { 'some_message' }
    let(:data_hash) { { a: 'some mesage ' } }
    let(:json) { { action: 'message', message: data } }
    it 'chats witout hash' do
      JSON.expects(:dump).with(json).returns(json)
      connection.expects(:text).with(json)
      @worker.send(:chat, data)
    end

    it 'chats with a hash' do
      connection.expects(:text).with(data_hash.to_json)
      @worker.send(:chat, data_hash)
    end
  end
end
