# PStore Logger

[![Gem Version](https://badge.fury.io/rb/pstore_logger.svg)](https://badge.fury.io/rb/pstore_logger)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D3.4.4-ruby.svg)](https://www.ruby-lang.org/en/)

A simple Ruby gem for logging data (webhooks, API responses, etc.) to organized PStore files with automatic timestamping and conflict resolution.

## Features

- 🚀 **Simple API**: Clean, intuitive interface for saving and loading data
- 📁 **Organized Storage**: Automatic directory creation with tag-based organization
- ⏰ **Automatic Timestamping**: YYYY-MM-DD-HH-MM-SS filename format
- 🔄 **Collision Handling**: Automatic conflict resolution with numbered suffixes
- 💾 **Flexible Data**: Store any Ruby object that can be serialized by PStore
- 🏷️ **Tagging System**: Organize logs by category/type using tags
- 📊 **Last Entry Retrieval**: Easy access to the most recent log entry
- 🧹 **No dependencies**: This gem has no external dependencies.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pstore_logger'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install pstore_logger
```

## Usage

### Basic Setup

```ruby
require 'pstore/logger'

# Initialize with a storage path and tag
logger = PStoreLogger.new(storage_path: '/path/to/logs', tag: 'webhooks')
```

### Saving Data

#### With Automatic Timestamp

```ruby
# Saves to: /path/to/logs/webhooks/2025-06-19-14-30-25.pstore
webhook_data = { event: 'user.created', user_id: 123, email: 'user@example.com' }
logger.save(webhook_data)
```

#### With Custom File ID

```ruby
# Saves to: /path/to/logs/webhooks/user_123.pstore
logger.save(webhook_data, file_id: 'user_123')

# If file exists, creates: user_123_1.pstore, user_123_2.pstore, etc.
logger.save(more_data, file_id: 'user_123')
```

### Loading Data

```ruby
# Load the most recent entry
latest_webhook = logger.load_last
puts latest_webhook # => { event: 'user.created', user_id: 123, ... }
```

## Real-World Examples

### Webhook Logger

```ruby
require 'pstore/logger'

class WebhookHandler
  def initialize
    @logger = PStoreLogger.new(
      storage_path: './logs/webhooks',
      tag: 'stripe'
    )
  end

  def handle_stripe_webhook(payload)
    @logger.save(payload, file_id: payload[:id])

    # Process the webhook
    process_payment(payload)
  end

  def debug_last_webhook
    @logger.load_last
  end
end
```

### API Response Caching

```ruby
require 'pstore/logger'

class ApiClient
  def initialize
    @cache = PStoreLogger.new(
      storage_path: './cache/api_responses',
      tag: 'github'
    )
  end

  def fetch_user(username)
    response = api_call("/users/#{username}")

    @cache.save(response, file_id: username)

    response
  end
end
```

### Development Testing

```ruby
require 'pstore/logger'

# Save test data during development
test_logger = PStoreLogger.new(storage_path: './tmp/test_data', tag: 'fixtures')

# Save complex test objects
user_data = { id: 1, name: 'Test User', preferences: { theme: 'dark' } }
test_logger.save(user_data, file_id: 'test_user')

# Later, load the test data
test_user = test_logger.load_last
```

## Data Structure

Each PStore file contains:

```ruby
{
  data: your_saved_object,      # Your original data
  timestamp: Time.now           # When it was saved
}
```

## Use Cases

- **🔗 Webhook Debugging**: Capture and inspect webhook payloads
- **📡 API Response Logging**: Store API responses for offline analysis
- **🔍 Data Auditing**: Keep records of data changes over time
- **🧪 Development Testing**: Persist test data between runs
- **📊 Data Analysis**: Collect data samples for analysis
- **🚨 Error Investigation**: Log problematic data for debugging

## Requirements

- Ruby >= 3.4.4
- No additional dependencies (uses built-in PStore)

## Development

After checking out the repo, run:

```bash
bundle install
```

To run the tests:

```bash
bundle exec ruby -Ilib:test test/test_pstore_logger.rb
```

To run linting:

```bash
bundle exec rubocop
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lucianghinda/pstore_logger.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.
