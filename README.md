# Kount

## Usage

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

client.create_order({
  merchant_order_id: 'myorderid',
  device_session_id: 'dis',
  creation_date_time: "2024-03-21T10:46:22Z",
  user_ip: "163.116.253.48",
  transactions: [{
    payment: {
      type: "CREDIT_CARD",
      bin: "483312",
      last4: "1111"
    },
    order_total: 100,
    currency: "USD",
    billed_person: {
      name: {
        first: "Jimmy",
        last: "Jazz"
      },
      email_address: "jjazz@kount.com",
      phone_number: "+15551234567",
      address: {
        address_type: "BILLING",
        line1: "1010 Main street",
        line2: "string",
        city: "Boise",
        region: "ID",
        postal_code: "83701",
        country_code: "US"
      }},
      transaction_status: "PENDING"
  }]
})
```
