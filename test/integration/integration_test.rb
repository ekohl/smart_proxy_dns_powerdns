require 'test_helper'

require 'ipaddr'
require 'net/http'

class DnsPowerdnsIntegrationTest < Test::Unit::TestCase

  def test_forward_dns
    data = {'fqdn' => fqdn, 'value' => ip, 'type' => 'A'}
    type = Resolv::DNS::Resource::IN::A
    expected = type.new(Resolv::IPv4.create(data['value']))

    test_scenario(data, data['fqdn'], type, expected)
  end

  def test_reverse_dns_v4
    data = {'fqdn' => fqdn, 'value' => IPAddr.new(ip).reverse, 'type' => 'PTR'}
    type = Resolv::DNS::Resource::IN::PTR
    expected = type.new(Resolv::DNS::Name.create(data['fqdn'] + '.'))

    test_scenario(data, data['value'], type, expected)
  end

  def test_reverse_dns_v6
    data = {'fqdn' => fqdn, 'value' => IPAddr.new(ipv6).reverse, 'type' => 'PTR'}
    type = Resolv::DNS::Resource::IN::PTR
    expected = type.new(Resolv::DNS::Name.create(data['fqdn'] + '.'))

    test_scenario(data, data['value'], type, expected)
  end

  private

  def test_scenario(data, name, type, expected)
    uri = URI(smart_proxy_url)

    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Post.new(smart_proxy_url + 'dns/')
      request.form_data = data
      response = http.request request
      assert_equal(200, response.code.to_i, response.body)

      assert_equal([expected], resolver.getresources(name, type))

      request = Net::HTTP::Delete.new(smart_proxy_url + 'dns/' + name)
      response = http.request request
      assert_equal(200, response.code.to_i, response.body)

      assert(purge_cache name)

      assert_equal([], resolver.getresources(name, type), name)
    end
  end

  def resolver
    host = ENV['PDNS_HOST'] || '127.0.0.1'
    port = ENV['PDNS_PORT'] || 5300
    Resolv::DNS.new(:nameserver_port => [[host, port.to_i]])
  end

  def smart_proxy_url
    ENV['SMARTPROXY_URL'] || 'http://localhost:8000/'
  end

  def fqdn
    set = ('a' .. 'z').to_a + ('0' .. '9').to_a
    10.times.collect {|i| set[rand(set.size)] }.join + '.example.com'
  end

  def ip
    IPAddr.new(rand(2 ** 32), Socket::AF_INET).to_s
  end

  def ipv6
    IPAddr.new(rand(2 ** 128), Socket::AF_INET6).to_s
  end

  def purge_cache name
    %x{#{ENV['PDNS_CONTROL'] || "pdns_control #{ENV['PDNS_ARGS']}"} purge "#{name}"}
    sleep 60 unless $? == 0
    sleep 1
    true
  end
end
