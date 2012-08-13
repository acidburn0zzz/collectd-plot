require 'httparty'
require 'redis'
require 'collectd-plot/cache'

# Read RRD data from remote shards.
# cache the data in redis.

module CollectdPlot
  module RRDRemote


    def self.list_hosts()
      CollectdPlot::Config.rrd_servers.map { |h| hosts_for_shard(h) }.flatten
    end

    def self.shard_index
      {}.tap do |res|
        CollectdPlot::Config.rrd_servers.each do |s|
          res[s] = hosts_for_shard s
        end
      end
    end

    def self.hosts_for_shard(s)
      CollectdPlot::Cache.instance.get("shard_for_host.#{s}") do
        http_get_json "#{s}/hosts"
      end
    end

    def self.hosts_to_shards
      {}.tap do |res|
        shard_index.each_pair do |shard, hosts|
          hosts.each do |host|
            res[host] ||= []
            res[host] << shard
          end
        end
      end
    end

    def self.shards_for_host(h)
      CollectdPlot::Cache.instance.get("shards_for_host.#{h}") do
        [].tap do |res|
          shard_index.each_pair do |shard, hosts|
            res << shard if hosts.include? h
          end
        end
      end
    end

    def self.shard_for_host(h)
      shards = shards_for_host h
      shards.empty? ? nil : shards.first
    end

    def self.rrd_file(host, plugin, instance, rrd)
      shard = shard_for_host host
      uri = "#{shard}/rrd/#{host}/#{plugin}/#{instance}/#{rrd}"
      res = CollectdPlot::Cache.instance.get("rrd.#{uri}") do
        { 'rrd' => http_get(uri) }
      end
      res['rrd']
    end

    def self.list_metrics_for(host)
      shard = shard_for_host host
      uri = "#{shard}/host/#{host}"
      CollectdPlot::Cache.instance.get("host.#{host}") do
        http_get_json uri
      end
    end

    def self.http_get_json(uri)
      JSON.parse(http_get uri, :headers => {:accept => 'application/json'})
    end

    def self.http_get(uri, opts)
      resp = HTTParty.get uri, opts
      raise "bad response for #{uri}" unless resp.code == 200
      resp.body
    end

    def self.cache_put_hosts_for_shard(shard, hosts)
      key = "hosts_for_shard.#{shard}"
      CollectdPlot::Cache.instance.put(key, hosts.sort.to_json, 600)
    end

    def self.cache_put_shard_for_host(host, shard)
      key = "shard_for_host.#{host}"
      CollectdPlot::Cache.instance.put(key, shard, 600)
    end

  end
end
