# encoding:utf-8

require 'spec_helper'

describe CelluloidPubsub::Client do
  let(:blk) { proc { |a| puts a } }
  let(:options) { {} }
  let(:actor) { double('actor') }
  let(:connection) { double('connection') }
  let(:channel) { 'some_channel' }
  let(:additional_options) { {} }

  before(:each) do
    allow_any_instance_of(CelluloidPubsub::Client).to receive(:supervise_actors).and_return(true)
    allow_any_instance_of(CelluloidPubsub::Client).to receive(:connection).and_return(connection)
    allow(actor).to receive(:async).and_return(actor)
    allow(actor).to receive(:terminate).and_return(true)
    allow(connection).to receive(:terminate).and_return(true)
    allow(connection).to receive(:text).and_return(true)
    allow(connection).to receive(:alive?).and_return(true)
    @worker = CelluloidPubsub::Client.new(additional_options.merge(actor: actor, channel: channel, enable_debug: false))
    @own_self = @worker.own_self
    allow(@own_self).to receive(:debug).and_return(true)
    allow(@own_self).to receive(:async).and_return(@worker)
  end

  describe '#initialize' do
    it 'creates a object' do
      expect(@own_self.channel).to eq channel
      expect(@own_self.actor).to eq actor
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
      expect(@own_self).to receive(:chat).with('client_action' => 'subscribe', 'channel' => channel)
      @worker.subscribe(channel)
    end
  end

  describe '#succesfull_subscription?' do
    let(:message) { double(present?: true) }
    let(:action) { double }

    before(:each) do
      allow(message).to receive(:[]).with('client_action').and_return('successful_subscription')
    end

    it 'checks the message and returns true' do
      expect(message).to receive(:is_a?).with(Hash).and_return(true)
      allow(message).to receive(:[]).with('client_action').and_return('successful_subscription')
      actual = @worker.succesfull_subscription?(message)
      expect(actual).to eq(true)
    end

    it 'checks the message and returns false' do
      expect(message).to receive(:is_a?).with(Hash).and_return(true)
      allow(message).to receive(:[]).with('client_action').and_return('something_else')
      actual = @worker.succesfull_subscription?(message)
      expect(actual).to eq(false)
    end
  end

  describe '#publish' do
    let(:channel) { 'some_channel' }
    let(:data) { 'some_message' }
    it 'chats with the server' do
      expect(@own_self).to receive(:send_action).with('publish', channel, data)
      @worker.publish(channel, data)
    end
  end

  describe '#unsubscribe' do
    let(:channel) { 'some_channel' }
    it 'chats with the server' do
      expect(@own_self).to receive(:send_action).with('unsubscribe', channel)
      @worker.unsubscribe(channel)
    end
  end

  describe '#unsubscribe_clients' do
    let(:channel) { 'some_channel' }
    it 'chats with the server' do
      expect(@own_self).to receive(:send_action).with('unsubscribe_clients', channel)
      @worker.unsubscribe_clients(channel)
    end
  end

  describe '#unsubscribe_all' do
    it 'chats with the server' do
      expect(@own_self).to receive(:send_action).with('unsubscribe_all')
      @worker.unsubscribe_all
    end
  end

  describe '#supervise_actors' do
    before do
      allow_any_instance_of(CelluloidPubsub::Client).to receive(:supervise_actors).and_call_original
    end

    it 'supervises the actor' do
      allow(actor).to receive(:respond_to?).with(:link).and_return(true)
      expect(actor).to receive(:link).with(@worker)
      expect(@worker).to receive(:link).with(connection)
      @worker.supervise_actors
    end

    it 'does not link the actor if not possible' do
      allow(actor).to receive(:respond_to?).with(:link).and_return(false)
      expect(actor).to_not receive(:link).with(@worker)
      expect(@worker).to receive(:link).with(connection)
      @worker.supervise_actors
    end
  end

  describe '#on_open' do
    let(:channel) { 'some_channel' }
    let(:data) { 'some_message' }
    it 'chats with the server' do
      expect(@own_self).to receive(:subscribe).with(channel)
      @worker.on_open
    end
  end

  describe '#on_message' do
    let(:channel) { 'some_channel' }
    let(:data) { 'some_message' }
    it 'chats with the server' do
      expect(JSON).to receive(:parse).with(data).and_return(data)
      expect(@own_self.actor).to receive(:respond_to?).and_return(true)
      expect(@own_self.actor).to receive(:async).and_return(actor)
      expect(@own_self.actor).to receive(:on_message).with(data)
      @worker.on_message(data)
    end

    it 'chats with the server without async' do
      expect(JSON).to receive(:parse).with(data).and_return(data)
      expect(@own_self.actor).to receive(:respond_to?).and_return(false)
      expect(@own_self.actor).to receive(:on_message).with(data)
      @worker.on_message(data)
    end
  end

  describe '#on_close' do
    let(:channel) { 'some_channel' }
    let(:code) { 'some_code' }
    let(:reason) { 'some_reason' }

    it 'chats with the server' do
      expect(actor).to receive(:on_close).with(code, reason).and_return(true)
      @worker.on_close(code, reason)
    end

    it 'chats with the server' do
      expect(actor).to receive(:respond_to?).with(:async).and_return(false)
      expect(actor).to receive(:on_close).with(code, reason).and_return(true)
      @worker.on_close(code, reason)
    end
  end

  describe '#chat' do
    let(:channel) { 'some_channel' }
    let(:data) { 'some_message' }
    let(:data_hash) { { a: 'some mesage ' } }
    let(:json) { { action: 'message', message: data } }
    it 'chats without hash' do
      expect(JSON).to receive(:dump).with(json).and_return(json)
      expect(connection).to receive(:text).with(json)
      @worker.send(:chat, data)
    end

    it 'chats with a hash' do
      expect(connection).to receive(:text).with(data_hash.to_json)
      @worker.send(:chat, data_hash)
    end
  end

  describe 'shutting_down?' do
    it 'returns false by default' do
      expect(@worker.shutting_down?).to eq(false)
    end

    it 'returns true' do
      allow(@own_self).to receive(:terminate).and_return(true)
      expect { @worker.shutdown }.to change(@worker, :shutting_down?).from(false).to(true)
    end

    it 'returns true when actor dies' do
      allow(@own_self).to receive(:shutdown).and_return(true)
      allow(@worker).to receive(:hostname).and_raise(RuntimeError)
      begin
        expect { @worker.hostname }.to change(@worker, :shutting_down?).from(false).to(true)
      rescue RuntimeError => e
        # do nothing
      end
    end
  end

  describe 'log_file_path' do
    it 'returns nil by default' do
      expect(@worker.log_file_path).to eq(nil)
    end

    context 'when log file path is defined' do
      let(:path) { '/some-path-here' }
      let(:additional_options) { { log_file_path: path } }

      it 'returns the path' do
        expect(@worker.log_file_path).to eq(path)
      end
    end
  end

  describe 'log_level' do
    it 'returns info by default' do
      expect(@worker.log_level).to eq(::Logger::Severity::INFO)
    end

    context 'when log level is defined' do
      let(:level) { Logger::Severity::DEBUG }
      let(:additional_options) { { log_level: level } }

      it 'returns the path' do
        expect(@worker.log_level).to eq(level)
      end
    end
  end

  describe 'path' do
    it 'returns the path of the server' do
      expect(@worker.path).to eq(CelluloidPubsub::WebServer::PATH)
    end

    context 'when path is defined' do
      let(:path) { '/demo' }
      let(:additional_options) { { path: path } }

      it 'returns the path' do
        expect(@worker.path).to eq(path)
      end
    end
  end

  describe 'connection' do
    it 'returns the path of the server' do
      allow_any_instance_of(CelluloidPubsub::Client).to receive(:connection).and_call_original
      expect(Celluloid::WebSocket::Client).to receive(:new).with("ws://#{@worker.hostname}:#{@worker.port}#{@worker.path}", @worker).and_return(connection)
      result = @worker.connection
      expect(result).to eq(connection)
    end
  end

  describe 'actor_died' do
    it 'sets the shutting down' do
      expect { @worker.send(:actor_died, @worker, nil) }.to change(@worker, :shutting_down?).from(false).to(true)
    end
  end
end
