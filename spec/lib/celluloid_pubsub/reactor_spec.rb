# encoding:utf-8

require 'spec_helper'

describe CelluloidPubsub::Reactor do
  let(:websocket) do
    double(
      'websocket',
      url: nil,
      read: nil,
      close: nil,
      closed?: false,
      present?: false
    )
  end
  let(:server_options) { {}.with_indifferent_access }
  let(:server) do
    double(
      'server',
      debug_enabled?: false,
      adapter: CelluloidPubsub::WebServer::CLASSIC_ADAPTER,
      server_options: server_options,
      dead?: false,
      subscribers: {},
      handle_dispatched_message: nil,
      mutex: mutex,
      timers_mutex: timers_mutex
    )
  end
  let(:mutex) { double('mutex') }
  let(:synchronizer) { double('synchronizer') }
  let(:timers_mutex) { double('timers_mutex') }
  let(:timers_synchronizer) { double('timers_synchronizer') }

  before(:each) do
    allow(server).to receive(:async).and_return(server)
    allow(actor).to receive(:async).and_return(actor)
    allow(actor).to receive(:inspect).and_return(actor)
    allow(actor).to receive(:run)
    allow(actor).to receive(:unsubscribe_from_channel).and_return(true)
    allow(mutex).to receive(:synchronize).and_yield
    allow(timers_mutex).to receive(:synchronize).and_yield
    allow(Celluloid::Actor).to receive(:kill).and_return(true)
    allow_any_instance_of(CelluloidPubsub::Reactor).to receive(:shutdown).and_return(true)
  end

  after(:each) do
    Celluloid.shutdown
  end

  let(:actor) { CelluloidPubsub::Reactor.new.initialize_data(websocket, server) }
  subject { actor.own_self }

  describe '#work' do
    it 'works ' do
      expect(actor).to receive(:run)
      actor.work(websocket, server)
      expect(actor.websocket).to eq(websocket)
      expect(actor.server).to eq(server)
      expect(actor.channels).to eq([])
    end
  end

  #  describe '#rub' do
  #    let(:data) { 'some message' }
  #
  #    it 'works ' do
  #      actor.unstub(:run)
  #      allow(websocket).to receive(:read).and_return(data)
  #        expect(subject).to receive(:handle_websocket_message).with(data)
  #      actor.run
  #    end
  #  end

  describe '#parse_json_data' do
    let(:data) { 'some message' }
    let(:expected) { data.to_json }

    it 'works with hash ' do
      expect(JSON).to receive(:parse).with(data).and_return(expected)
      actual = actor.parse_json_data(data)
      expect(actual).to eq expected
    end

    it 'works with exception parsing  ' do
      expect(JSON).to receive(:parse).with(data).and_raise(StandardError)
      actual = actor.parse_json_data(data)
      expect(actual).to eq data
    end
  end

  describe '#handle_websocket_message' do
    let(:data) { 'some message' }
    let(:json_data) { { a: 'b' } }

    it 'handle_websocket_message' do
      expect(subject).to receive(:parse_json_data).with(data).and_return(json_data)
      expect(subject).to receive(:handle_parsed_websocket_message).with(json_data)
      actor.handle_websocket_message(data)
    end
  end

  describe '#handle_parsed_websocket_message' do
    it 'handle_websocket_message with a hash' do
      data = { 'client_action' => 'subscribe', 'channel' => 'test' }
      expect(data).to receive(:stringify_keys).and_return(data)
      expect(subject).to receive(:delegate_action).with(data).and_return(true)
      actor.handle_parsed_websocket_message(data)
    end

    it 'handle_websocket_message with something else than a hash' do
      data = { 'message' => 'some message' }
      expect(subject).to receive(:handle_unknown_action).with(data['channel'], data).and_return(true)
      actor.handle_parsed_websocket_message(data)
    end
  end

  describe '#delegate_action' do
    before(:each) do
      allow(subject).to receive(:unsubscribe_clients).and_return(true)
      allow(subject).to receive(:shutdown).and_return(true)
    end

    it 'unsubscribes all' do
      data = { 'client_action' => 'unsubscribe_all', 'channel' => '' }
      expect(subject).to receive(:send).with(data['client_action'], data['channel'], data).and_return('bla')
      actor.delegate_action(data)
    end

    it 'unsubscribes all' do
      data = { 'client_action' => 'unsubscribe', 'channel' => 'some channel' }
      expect(subject).to receive(:send).with(data['client_action'], data['channel'], data)
      actor.delegate_action(data)
    end
    it 'subscribes to channell' do
      data = { 'client_action' => 'subscribe', 'channel' => 'some channel' }
      expect(subject).to receive(:send).with(data['client_action'], data['channel'], data)
      actor.delegate_action(data)
    end

    it 'publish' do
      data = { 'client_action' => 'publish', 'channel' => 'some channel', 'data' => 'some data' }
      expect(subject).to receive(:send).with(data['client_action'], data['channel'], data)
      actor.delegate_action(data)
    end
  end
  describe '#handle_unknown_action' do
    it 'handles unknown' do
      data = 'some data'
      channel = 'some_channel'
      expect(server).to receive(:handle_dispatched_message)
      actor.handle_unknown_action(channel, data)
    end
  end

  describe '#unsubscribe_client' do
    let(:channel) { 'some channel' }
    let(:data) { { 'client_action' => 'unsubscribe', 'channel' => channel } }
    it 'returns nil' do
      act = actor.unsubscribe('', data)
      expect(act).to eq(nil)
    end

    it 'unsubscribes' do
      allow(channel).to receive(:present?).and_return(true)
      expect(subject).to receive(:forget_channel).with(channel)
      expect(subject).to receive(:delete_server_subscribers).with(channel)
      act = actor.unsubscribe(channel, data)
      expect(act).to eq(nil)
    end
  end

  describe '#delete_server_subscribers' do
    let(:channel) { 'some channel' }

    before(:each) do
      allow(server).to receive(:subscribers).and_return(channel.to_s => [{ reactor: actor }])
    end

    it 'unsubscribes' do
      act = actor.delete_server_subscribers(channel)
      expect(server.subscribers[channel]).to eq([])
    end
  end

  describe '#forget_channel' do
    let(:channel) { 'some channel' }

    it 'unsubscribes' do
      allow(actor.channels).to receive(:blank?).and_return(true)
      expect(actor.websocket).to receive(:close)
      act = actor.forget_channel(channel)
      expect(act).to eq(nil)
    end

    it 'unsubscribes' do
      allow(actor.channels).to receive(:blank?).and_return(false)
      expect(actor.channels).to receive(:delete).with(channel)
      #  allow(server).to receive(:subscribers).and_return("#{channel}" => [{ reactor: subject }])
      actor.forget_channel(channel)
      #  expect(server.subscribers[channel]).to eq([])
    end
  end

  describe '#shutdown' do
    before(:each)  do
      allow_any_instance_of(CelluloidPubsub::Reactor).to receive(:shutdown).and_call_original
    end

    it 'shutdowns' do
      expect(subject).to receive(:terminate).at_least(:once)
      actor.shutdown
    end
  end

  describe '#start_subscriber' do
    let(:channel) { 'some channel' }
    let(:message) { { a: 'b' } }

    it 'subscribes ' do
      act = actor.subscribe('', message)
      expect(act).to eq(nil)
    end

    it 'subscribes ' do
      allow(subject).to receive(:add_subscriber_to_channel).with(channel, message)
      allow(server).to receive(:redis_enabled?).and_return(false)
      expect(actor.websocket).to receive(:<<).with(message.merge('client_action' => 'successful_subscription', 'channel' => channel).to_json)
      actor.subscribe(channel, message)
    end

    #    it 'raises error' do
    #      subject).to receive(:add_subscriber_to_channel).raises(StandardError)
    #
    #      expect do
    #        actor.start_subscriber(channel, message)
    #      end.to raise_error(StandardError) { |e|
    #        expect(e.message).to include(channel)
    #      }
    #    end
  end

  describe '#add_subscriber_to_channel' do
    let(:channel) { 'some channel' }
    let(:message) { { a: 'b' } }
    let(:subscribers) { double }

    it 'adds subscribed' do
      allow(CelluloidPubsub::Registry.channels).to receive(:include?).with(channel).and_return(false)
      expect(CelluloidPubsub::Registry.channels).to receive(:<<).with(channel)
      expect(subject).to receive(:channel_subscribers).with(channel).and_return(subscribers)
      expect(subscribers).to receive(:push).with(reactor: actor, message: message)
      actor.add_subscriber_to_channel(channel, message)
      expect(actor.channels).to include(channel)
    end
  end

  describe '#unsubscribe_all' do
    let(:channel) { 'some channel' }
    let(:message) { { a: 'b' } }

    it 'adds subscribed' do
      allow(CelluloidPubsub::Registry).to receive(:channels).and_return([channel])
      expect(subject).to receive(:unsubscribe_from_channel).with(channel).and_return(true)
      actor.unsubscribe_all(channel, message)
    end
  end

  describe 'log_file_path' do
    it 'returns nil by default' do
      expect(actor.log_file_path).to eq(nil)
    end

    context 'when log file path is defined' do
      let(:path) { '/some-path-here' }
      let(:server_options) { { log_file_path: path }.with_indifferent_access }

      it 'returns the path' do
        expect(actor.log_file_path).to eq(path)
      end
    end
  end

  describe 'log_level' do
    it 'returns info by default' do
      expect(actor.log_level).to eq(::Logger::Severity::INFO)
    end

    context 'when log level is defined' do
      let(:level) { Logger::Severity::DEBUG }
      let(:server_options) { { log_level: level }.with_indifferent_access }

      it 'returns the path' do
        expect(actor.log_level).to eq(level)
      end
    end
  end

  describe 'adapter options' do
    it 'returns info by default' do
      expect(actor.adapter_options).to eq({})
    end

    context 'when log level is defined' do
      let(:adapter_options) { { something: :here, another: { key: :value } } }
      let(:server_options) { { adapter_options: adapter_options }.with_indifferent_access }

      it 'returns the path' do
        expect(actor.adapter_options).to eq(adapter_options.deep_stringify_keys)
      end
    end
  end

  describe 'shutting_down?' do
    before(:each)  do
      allow_any_instance_of(CelluloidPubsub::Reactor).to receive(:shutdown).and_call_original
    end

    it 'returns false by default' do
      expect(actor.shutting_down?).to eq(false)
    end

    it 'returns true' do
      allow(subject).to receive(:terminate).and_return(true)
      expect { actor.shutdown }.to change(actor, :shutting_down?).from(false).to(true)
    end

    it 'returns true when actor dies' do
      allow(subject).to receive(:shutdown).and_return(true)
      allow(actor).to receive(:log_level).and_raise(RuntimeError)
      begin
        expect { actor.log_level }.to change(actor, :shutting_down?).from(false).to(true)
      rescue RuntimeError => e
        # do nothing
      end
    end
  end

  describe 'try_read_websocket' do
    it 'returns nil if socket closed' do
      allow(websocket).to receive(:closed?).and_return(true)
      expect(websocket).to_not receive(:read)
      result = actor.try_read_websocket
      expect(result).to eq(nil)
    end

    it 'reads the socket' do
      expected = 'something'
      allow(websocket).to receive(:closed?).and_return(false)
      expect(websocket).to receive(:read).and_return(expected)
      result = actor.try_read_websocket
      expect(result).to eq(expected)
    end

    it 'returns nil if socket closed' do
      allow(websocket).to receive(:closed?).and_return(false)
      expect(websocket).to receive(:read).and_raise(StandardError)
      result = actor.try_read_websocket
      expect(result).to eq(nil)
    end
  end

  describe 'send_unpublshed' do
    let(:channel) { 'test' }
    let(:messages) { [1, 2, 3] }

    it 'does not send if no messages' do
      allow(subject).to receive(:unpublished_messages).with(channel).and_return(nil)
      expect(websocket).to_not receive(:<<)
      subject.send_unpublished(channel)
    end

    it 'sends the messages' do
      allow(subject).to receive(:unpublished_messages).with(channel).and_return(messages)
      messages.each do |msg|
        expect(websocket).to receive(:<<).ordered.with(msg.to_json)
      end
      subject.send_unpublished(channel)
    end
  end

  describe 'clears the messages' do
    let(:channel) { 'test' }
    let(:messages) { [1, 2, 3] }

    before do
      CelluloidPubsub::Registry.messages[channel] = messages
    end

    after do
      CelluloidPubsub::Registry.messages = {}
    end

    it 'clears the messages' do
      actor.clear_unpublished_messages(channel)
      expect(CelluloidPubsub::Registry.messages).to eq(channel => [])
    end
  end

  describe 'unpublished_messages' do
    let(:channel) { 'test' }
    let(:messages) { [1, 2, 3] }

    before do
      CelluloidPubsub::Registry.messages[channel] = messages
    end

    after do
      CelluloidPubsub::Registry.messages = {}
    end

    it 'retrieves the messages' do
      result = actor.unpublished_messages(channel)
      expect(result).to eq(messages)
    end

    it 'returns empty array for non existing channel' do
      result = actor.unpublished_messages('something-here')
      expect(result).to eq([])
    end
  end

  describe 'subscribers' do
    let(:channel) { 'test' }
    before do
      server.subscribers[channel] = [{ reactor: actor }]
    end

    it 'returns empty array' do
      result = actor.channel_subscribers('some-channel')
      expect(result).to eq([])
    end

    it 'returns the subscribers' do
      result = actor.channel_subscribers(channel)
      expect(result).to eq([{ reactor: actor }])
    end
  end

  describe 'publish' do
    let(:channel) { 'test' }
    let(:data) { { 'client_action' => 'publish', 'channel' => 'test_channel', 'data' => { 'data' => ' my_message' } } }

    it 'publishes the message' do
      expect(subject).to receive(:server_publish_event).with(channel, data['data'].to_json)
      actor.publish(channel, data)
    end

    it 'does not publish if channel is blank' do
      expect(subject).to_not receive(:server_publish_event)
      actor.publish(nil, data)
    end

    it 'publishes null' do
      expect(subject).to receive(:server_publish_event).with(channel, 'null')
      actor.publish(channel, data.except('data'))
    end

    it 'catches error' do
      expect(subject).to receive(:server_publish_event).and_raise(StandardError)
      expect(subject).to receive(:log_debug)
      actor.publish(channel, data.except('data'))
    end
  end

  describe 'server_publish_event' do
    let(:actor2) { CelluloidPubsub::Reactor.new.initialize_data(websocket, server) }
    let(:subject2) { actor2.own_self }

    let(:channel) { 'test' }
    let(:message) { '1' }
    before do
      server.subscribers[channel] = [{ reactor: actor }, { reactor: actor2 }]
    end

    it 'published message to channel' do
      server.subscribers[channel].each do |hash|
        expect(hash[:reactor].websocket).to receive(:<<).with(message)
      end
      actor.server_publish_event(channel, message)
    end

    it 'saves the mesages if no subscribers' do
      channel2 = 'some-channel'
      expect(subject).to receive(:save_unpublished_message).with(channel2, message).and_call_original
      actor.server_publish_event(channel2, message)
      expect(CelluloidPubsub::Registry.messages).to eq(channel2 => [message])
    end
  end
  describe 'unsubscribe_from_channel' do
    let(:channel) { 'test' }
    it 'kills the reactors' do
      expect(subject).to receive(:server_kill_reactors).with(channel)
      subject.unsubscribe_from_channel(channel)
    end
  end

  describe 'server_kill_reactors' do
    let(:actor2) { CelluloidPubsub::Reactor.new.initialize_data(websocket, server) }
    let(:subject2) { actor2.own_self }

    let(:channel) { 'test' }

    before do
      server.subscribers[channel] = [{ reactor: actor }, { reactor: actor2 }]
    end

    it 'kills the reactors' do
      server.subscribers[channel].each do |hash|
        expect(hash[:reactor].websocket).to receive(:close)
        expect(Celluloid::Actor).to receive(:kill).ordered.with(hash[:reactor])
      end
      actor.server_kill_reactors(channel)
    end
  end
  describe 'actor_died' do
    it 'sets the shutting down' do
      expect { actor.send(:actor_died, actor, nil) }.to change(actor, :shutting_down?).from(false).to(true)
    end
  end
end
