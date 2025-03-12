# Kount
> Ruby interface to the Kount Orders API 

## Configuration

```ruby
require "kount"
require "kount/adapters/redis_adapter"  # Optional adapter – ensure the 'redis' gem is in your Gemfile.

redis_adapter = Kount::Adapters::RedisAdapter.new(Redis.new)

client = Kount::Client.new(
  api_key: "your_api_key",
  auth_url: "https://login.kount.com/oauth2/your_auth_endpoint",
  api_domain: "https://api-sandbox.kount.com",
  token_storage_adapter: redis_adapter
)
```

## Methods

```
#create_order -> Kount::Response
#update_order -> Kount::Response
```
