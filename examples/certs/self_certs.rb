require 'rubygems'
require 'bundler/setup'
require 'fileutils'
require 'pathname'

require 'openssl'
certs_dir = Pathname.new File.expand_path('../../tmp/certs', __FILE__)
FileUtils.mkdir_p(certs_dir)


class SelfSignedCertificate
  def initialize
    @key = OpenSSL::PKey::RSA.new(1024)
    public_key = @key.public_key

    subject = "/C=BE/O=Test/OU=Test/CN=Test"

    @cert = OpenSSL::X509::Certificate.new
    @cert.subject = @cert.issuer = OpenSSL::X509::Name.parse(subject)
    @cert.not_before = Time.now
    @cert.not_after = Time.now + 365 * 24 * 60 * 60
    @cert.public_key = public_key
    @cert.serial = 0x0
    @cert.version = 2

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = @cert
    ef.issuer_certificate = @cert
    @cert.extensions = [
        ef.create_extension("basicConstraints","CA:TRUE", true),
        ef.create_extension("subjectKeyIdentifier", "hash"),
    # ef.create_extension("keyUsage", "cRLSign,keyCertSign", true),
    ]
    @cert.add_extension ef.create_extension("authorityKeyIdentifier",
                                           "keyid:always,issuer:always")

    @cert.sign @key, OpenSSL::Digest::SHA1.new
  end

  def self_signed_pem
    @cert.to_pem
  end

  def private_key
    @key
  end
end

my_cert = SelfSignedCertificate.new

server_cert_path = File.join(certs_dir, 'server.crt')
server_key_path  = File.join(certs_dir, 'server.key')

File.write server_cert_path, my_cert.self_signed_pem
File.write server_key_path,  my_cert.private_key
