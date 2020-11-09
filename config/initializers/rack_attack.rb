if Rails.env.production?
  # Only enable throttling if REDIS_URL is set
  if ENV['REDIS_URL']
    Redis.current = Redis.new(url: ENV['REDIS_URL'])
    # Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(Redis.current)
  end

  module Rack
    class Attack
      throttle('limit requests per IP', limit: 60, period: 1.minute) do |req|
        req.ip unless req.path.start_with?('/assets', '/rails/active_storage')
      end
    end
  end
end
