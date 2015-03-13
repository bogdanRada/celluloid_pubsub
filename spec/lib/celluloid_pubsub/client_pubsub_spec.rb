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

  before(:each) do
    Celluloid::WebSocket::Client.stubs(:new).returns(socket)
    socket.stubs(:text)
    @worker = CelluloidPubsub::Client::PubSubWorker.new({ 'actor' => 'actor' }, &blk)
    @worker.stubs(:debug)
    @worker.stubs(:async).returns(@worker)
  end

  describe '#initialize' do
    it 'creates a object' do
      @worker.connect_blk.should_not be_nil
      @worker.actor.should eq 'actor'
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
      CelluloidPubsub::WebServer.expects(:debug_enabled?).returns(true)
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

  describe '#publish' do
    let(:channel) { 'some_channel' }
    let(:data) { 'some_message' }
    it 'chats with the server' do
      @worker.expects(:chat).with('client_action' => 'publish', 'channel' => channel, 'data' => data)
      @worker.publish(channel, data)
    end
  end

  describe '#publish' do
    let(:channel) { 'some_channel' }
    let(:data) { 'some_message' }
    it 'chats with the server' do
      @worker.connect_blk.expects(:call)
      @worker.on_open
    end
  end
end
