# encoding:utf-8

require 'spec_helper'

describe CelluloidPubsub::WebServer do
  it 'should have host constant' do
    CelluloidPubsub::WebServer::HOST.should eq('0.0.0.0')
  end

  it 'should have host constant' do
    CelluloidPubsub::WebServer::PORT.should eq(1234)
  end

  it 'should have host constant' do
    CelluloidPubsub::WebServer::PATH.should eq('/ws')
  end
  let(:options) { {} }
  let(:web_server) { mock }

  before(:each) do
    CelluloidPubsub::WebServer.stubs(:super).returns(web_server)
  end

  it '#initialize with default values ' do
    server = CelluloidPubsub::WebServer.new(options)
    server.hostname.should eq(CelluloidPubsub::WebServer::HOST)
    server.port.should eq(CelluloidPubsub::WebServer::PORT)
    server.path.should eq(CelluloidPubsub::WebServer::PATH)
    server.backlog.should eq(1024)
    server.spy.should eq(false)
  end

  describe '#with custom values' do
    let(:hostname) { '192.0.0.1' }
    let(:port) { 13_456 }
    let(:path) { '/pathy' }
    let(:backlog) { 2048 }
    let(:spy) { true }

    it '#initialize with custom values ' do
      server = CelluloidPubsub::WebServer.new(hostname: hostname, port: port, path: path, spy: spy, backlog: backlog)
      server.hostname.should eq(hostname)
      server.port.should eq(port)
      server.path.should eq(path)
      server.backlog.should eq(backlog)
      server.spy.should eq(spy)
    end
  end
end
