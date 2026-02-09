require 'connection_pool'

# Configure Redis connection pool
# This is ideal for handling high-volume OCR processing and API ingress
REDIS = ConnectionPool::Wrapper.new(size: 5, timeout: 3) do
  Redis.new(
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    reconnect_attempts: 3,
    connect_timeout: 1,
    read_timeout: 1,
    write_timeout: 1
  )
end