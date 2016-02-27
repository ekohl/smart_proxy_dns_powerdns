require 'dns/dns'
require 'dns_common/dns_common'
require 'ipaddr'

module Proxy::Dns::Powerdns
  class Record < ::Proxy::Dns::Record
    include Proxy::Log
    include Proxy::Util

    attr_reader :pdnssec

    def initialize(a_server = nil, a_ttl = nil)
      @pdnssec = Proxy::Dns::Powerdns::Plugin.settings.powerdns_pdnssec
      super(a_server, a_ttl || Proxy::Dns::Plugin.settings.dns_ttl)
    end

    def create_a_record(fqdn, ip)
      case a_record_conflicts(fqdn, ip)
      when 1
        raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
      when 0 then
        return nil
      else
        do_create(fqdn, ip, "A")
      end
    end

    def create_ptr_record(fqdn, ptr)
      case ptr_record_conflicts(fqdn, ptr_to_ip(ptr))
      when 1
        raise(Proxy::Dns::Collision, "'#{fqdn} 'is already in use")
      when 0 then
        return nil
      else
        do_create(ptr, fqdn, "PTR")
      end
    end

    def do_create(name, value, type)
      zone = get_zone(name)
      create_record(zone['id'], name, type, value) and rectify_zone(zone['name'])
    end

    def remove_a_record(fqdn)
      do_remove(fqdn, "A")
    end

    def remove_ptr_record(ptr)
      do_remove(ptr, "PTR")
    end

    def do_remove(name, type)
      zone = get_zone(name)
      delete_record(zone['id'], name, type) and rectify_zone(zone['name'])
    end

    def get_zone(fqdn)
      # TODO: backend specific
      raise Proxy::Dns::Error, "Unable to determine zone. Zone must exist in PowerDNS."
    end

    def create_record(domain_id, name, type, content)
      # TODO: backend specific
      false
    end

    def delete_record(domain_id, name, type)
      # TODO: backend specific
      false
    end

    def rectify_zone domain
      if @pdnssec
        %x(#{@pdnssec} rectify-zone "#{domain}")

        $?.exitstatus == 0
      else
        true
      end
    end
  end
end
