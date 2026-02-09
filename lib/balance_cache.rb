# lib/balance_cache.rb
#
# Redis caching module for account balances
# Uses versioned cache keys with optimistic locking

module BalanceCache
  CACHE_TTL = 1.hour
  
  class << self
    # Get cached balance for an account
    def get(account_id, lock_version)
      key = cache_key(account_id, lock_version)
      
      cached = REDIS.get(key)
      return JSON.parse(cached)['balance'].to_f if cached
      
      nil
    rescue Redis::BaseError => e
      Rails.logger.error("Redis error in BalanceCache.get: #{e.message}")
      nil # Fallback to DB
    end
    
    # Set cached balance for an account
    def set(account_id, lock_version, balance)
      key = cache_key(account_id, lock_version)
      value = { 
        balance: balance, 
        cached_at: Time.current.to_i,
        account_id: account_id,
        lock_version: lock_version
      }
      
      REDIS.setex(key, CACHE_TTL.to_i, value.to_json)
      true
    rescue Redis::BaseError => e
      Rails.logger.error("Redis error in BalanceCache.set: #{e.message}")
      false # Don't fail transaction if Redis is down
    end
    
    # Invalidate all cache versions for an account
    def invalidate(account_id)
      # Delete all versions - brute force invalidation
      keys = REDIS.keys("account:#{account_id}:balance:*")
      REDIS.del(*keys) if keys.any?
      true
    rescue Redis::BaseError => e
      Rails.logger.error("Redis error in BalanceCache.invalidate: #{e.message}")
      false # Silent fail - cache will expire naturally
    end
    
    # Bulk get balances for multiple accounts
    def bulk_get(account_ids_with_versions)
      results = {}
      
      REDIS.pipelined do |pipeline|
        account_ids_with_versions.each do |account_id, lock_version|
          key = cache_key(account_id, lock_version)
          results[account_id] = pipeline.get(key)
        end
      end
      
      # Process results
      parsed_results = {}
      results.each do |account_id, future|
        value = future.value
        parsed_results[account_id] = JSON.parse(value)['balance'].to_f if value
      end
      
      parsed_results
    rescue Redis::BaseError => e
      Rails.logger.error("Redis error in BalanceCache.bulk_get: #{e.message}")
      {} # Return empty hash on error
    end
    
    # Bulk set balances for multiple accounts
    def bulk_set(account_balances)
      REDIS.pipelined do |pipeline|
        account_balances.each do |account_id, lock_version, balance|
          key = cache_key(account_id, lock_version)
          value = {
            balance: balance,
            cached_at: Time.current.to_i,
            account_id: account_id,
            lock_version: lock_version
          }
          pipeline.setex(key, CACHE_TTL.to_i, value.to_json)
        end
      end
      true
    rescue Redis::BaseError => e
      Rails.logger.error("Redis error in BalanceCache.bulk_set: #{e.message}")
      false
    end
    
    # Get cache statistics
    def stats
      info = REDIS.info
      {
        used_memory: info['used_memory_human'],
        connected_clients: info['connected_clients'],
        total_commands_processed: info['total_commands_processed'],
        keyspace_hits: info['keyspace_hits'],
        keyspace_misses: info['keyspace_misses'],
        hit_rate: calculate_hit_rate(info)
      }
    rescue Redis::BaseError => e
      Rails.logger.error("Redis error in BalanceCache.stats: #{e.message}")
      { error: 'Redis unavailable' }
    end
    
    # Clear all balance caches (use with caution!)
    def clear_all
      keys = REDIS.keys('account:*:balance:*')
      REDIS.del(*keys) if keys.any?
      keys.size
    rescue Redis::BaseError => e
      Rails.logger.error("Redis error in BalanceCache.clear_all: #{e.message}")
      0
    end
    
    private
    
    def cache_key(account_id, lock_version)
      "account:#{account_id}:balance:v#{lock_version}"
    end
    
    def calculate_hit_rate(info)
      hits = info['keyspace_hits'].to_i
      misses = info['keyspace_misses'].to_i
      total = hits + misses
      
      total > 0 ? (hits.to_f / total * 100).round(2) : 0
    end
  end
end
