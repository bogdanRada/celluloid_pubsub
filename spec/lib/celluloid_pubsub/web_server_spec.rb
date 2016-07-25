# encoding:utf-8

require 'spec_helper'

describe CelluloidPubsub::WebServer do
  it 'should have host constant' do
    expect(CelluloidPubsub::WebServer::HOST).to eq('0.0.0.0')
  end

  it 'should have host constant' do
    expect(CelluloidPubsub::WebServer::PATH).to eq('/ws')
  end
  let(:options) { {} }
  let(:web_server) { mock }

  before(:each) do
    CelluloidPubsub::WebServer.stubs(:new).returns(web_server)
  end

  #  it '#initialize with default values ' do
  #    web_server.parse_options({})
  #    web_server.hostname.should eq(CelluloidPubsub::WebServer::HOST)
  #    web_server.port.should eq(CelluloidPubsub::WebServer::PORT)
  #    web_server.path.should eq(CelluloidPubsub::WebServer::PATH)
  #    web_server.backlog.should eq(1024)
  #    web_server.spy.should eq(false)
  #  end
  #
  #  describe '#with custom values' do
  #    let(:hostname) { '192.0.0.1' }
  #    let(:port) { 13_456 }
  #    let(:path) { '/pathy' }
  #    let(:backlog) { 2048 }
  #    let(:spy) { true }
  #
  #    it '#initialize with custom values ' do
  #      web_server.parse_options(hostname: hostname, port: port, path: path, spy: spy, backlog: backlog)
  #      web_server.hostname.should eq(hostname)
  #      web_server.port.should eq(port)
  #      web_server.path.should eq(path)
  #      web_server.backlog.should eq(backlog)
  #      web_server.spy.should eq(spy)
  #    end
  #  end
end
