# encoding:utf-8

require 'spec_helper'

describe CelluloidPubsub::Client do
  let(:options) { {} }
  let(:blk) { proc { |a| puts a } }

  it 'runs the connect method' do
    expected = nil
    CelluloidPubsub::Client::PubSubWorker.stubs(:new).returns(expected)
    res = CelluloidPubsub::Client.connect(options, &blk)
    res.should eq expected
  end
end

describe CelluloidPubsub::Client::PubSubWorker do
  let(:blk) { proc { |a| puts a } }
  let(:options) { {} }
  let(:socket) { mock }
  let(:actor) { mock }

  before(:each) do
    Celluloid::WebSocket::Client.stubs(:new).returns(socket)
    socket.stubs(:text)
    @worker = CelluloidPubsub::Client::PubSubWorker.new({ 'actor' => actor, enable_debug: true }, &blk)
    @worker.stubs(:client).returns(socket)
    @worker.stubs(:debug)
    @worker.stubs(:async).returns(@worker)
    actor.stubs(:async).returns(actor)
  end

  describe '#initialize' do
    it 'creates a object' do
      @worker.connect_blk.should_not be_nil
      @worker.actor.should eq actor
    end
  end

  describe '#parse_options' do
    let(:actor) { mock }
    let(:hostname) { '127.0.0.1' }
    let(:port) { 9999 }
    let(:path) { '/some_path' }
    let(:custom_options) { { actor: actor, hostname: hostname, port: port, path: path } }

    it 'parses options' do
      @worker.parse_options(custom_options)
      @worker.actor.should eq(actor)
      @worker.hostname.should eq(hostname)
      @worker.port.should eq(port)
      @worker.path.should eq(path)
    end

    it 'sets defaults' do
      @worker.parse_options({})
      @worker.actor.should eq(nil)
      @worker.hostname.should eq('0.0.0.0')
      @worker.port.should eq(1234)
      @worker.path.should eq('/ws')
    end
  end

  describe '#debug_enabled?' do
    it 'checks if debug is enabled' do
      act = @worker.debug_enabled?
      act.should eq(true)
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
      message.expects(:present?).returns(true)
      message.stubs(:[]).with('client_action').returns('successful_subscription')
      actual = @worker.succesfull_subscription?(message)
      actual.should eq(true)
    end

    it 'checks the message and returns false' do
      message.expects(:present?).returns(true)
      message.stubs(:[]).with('client_action').returns('something_else')
      actual = @worker.succesfull_subscription?(message)
      actual.should eq(false)
    end
  end

  describe '#publish' do
    let(:channel) { 'some_channel' }
    let(:data) { 'some_message' }
    it 'chats with the server' do
      @worker.expects(:chat).with('client_action' => 'publish', 'channel' => channel, 'data' => data)
      @worker.publish(channel, data)
    end
  end

  describe '#on_open' do
    let(:channel) { 'some_channel' }
    let(:data) { 'some_message' }
    it 'chats with the server' do
      @worker.connect_blk.expects(:call)
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
    let(:code) { 'some_message' }
    let(:reason) { 'some reason' }

    it 'chats with the server' do
      @worker.client.expects(:terminate)
      @worker.actor.expects(:on_close).with(code, reason)
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
      @worker.client.expects(:text).with(json)
      @worker.send(:chat, data)
    end

    it 'chats with a hash' do
      @worker.client.expects(:text).with(data_hash.to_json)
      @worker.send(:chat, data_hash)
    end
  end
end
