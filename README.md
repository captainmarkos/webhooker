## WebHooker

A simple webhook system in Rails.


### Overview

In its simplest form, a webhook system is built on top of the pub/sub design pattern:
  - Some event `e` happens in our service, and we want to notify all subscribers `s`.

In the context of a webhook, an event `e` will consist of the following information:
  - An event - this will be an event name, for example `payment.successful`, `license.expired`, or `user.updated`.
  - A payload - this will be the data we'll be sending to subscribers. Typically, it's a snapshot of the affected resource. For example, the `user.updated` event may send a snapshot of the user after it was updated.

A subscriber `s` will consist of the following information:
  - A url - this will be the URL that the webhook is delivered to.

Since we don't know how big the set of `s` is, we don't want to run these notifications inline with our normal application code. Why? Because the bigger `s` is, the slower our app will be, and we also have no control over deliveribility speed, other than through setting an upper bound on webhook execution time with a timeout.

So rather than run inline, we'll need some sort of queueing and background job system so that we can asynchronously process notifications to each subscriber.

[Sidekiq](https://github.com/mperham/sidekiq) is powerful background job library that we'll be using to queue up webhook events and process them asynchronously. We'll also be leaning on Sidekiq to handle the bulk of our retry logic


### Create App and Setup

```bash
rails new webhooker \
  --api \
  --database sqlite3 \
  --skip-active-storage \
  --skip-action-cable
```

#### Add Gems
```ruby
gem 'sidekiq'
gem 'redis'
gem 'http'

# in development, test
gem 'pry-rails'
gem 'pry-byebug'
gem 'pry-theme'
gem 'rubocop', require: false
```

#### Turn off irb autocomplete in rails console

```bash
cat >> ~/.irbrc
IRB.conf[:USE_AUTOCOMPLETE] = false
```

The [pry-theme gem](https://github.com/kyrylo/pry-theme) adds some spice to the rails console.

```ruby
[1] pry(main)> pry-theme install vividchalk

[2] pry(main)> pry-theme try vividchalk

[3] pry(main)> s = WebhookSubscriber.create!(url: 'https://functions.ecorp.example/webhooks')

[4] pry(main)> e = WebhookEvent.create!(webhook_subscriber: s, event: 'events.test', payload: { test: 1 })

[5] pry(main)> WebhookWorker.new.perform(WebhookEvent.last.id)
```

```bash
cat >> .pryrc
Pry.config.theme = 'vividchalk'
# Pry.config.theme = 'tomorrow-night'
# Pry.config.theme = 'pry-modern-256'
# Pry.config.theme = 'ocean'
```


### Receiving Live Notification Messages


To receive live notification messages (referred to as LNM from here on out) we
need a server running that will listen for them.  For this particalur app we'll be
running a rails server that will be sending AND receiving LNMs so nothing else is needed.
However if we were only receiving LNMs then to test we would need a server to expose our
local dev environment rails server.  Here's a few options for local development.

- [ngrok](https://ngrok.com/)
- [localtunnel](https://localtunnel.github.io/www/)


For this we'll be using [ngrok](https://ngrok.com/).  After installing run the following

```bash
# use same port the rails server is using
$ ngrok http 3300
```

This will give us a 2 hour session.  Here's the output

```bash
ngrok by @inconshreveable                                                                     (Ctrl+C to quit)

Session Status            online
Session Expires           1 hour, 59 minutes
Version                   2.3.40
Region                    United States (us)
Web Interface             http://127.0.0.1:4040
Forwarding                http://128c-2601-583-701-b790-45b7-647b-44bb-5887.ngrok.io -> http://localhost:3000
Forwarding                https://128c-2601-583-701-b790-45b7-647b-44bb-5887.ngrok.io -> http://localhost:3000

Connections               ttl     opn     rt1     rt5     p50     p90
                          0       0       0.00    0.00    0.00    0.00
```

Start the Rails server and/or console passing the *Forwarding* url as an ENV (protocol not needed)

```bash
WEBHOOKS_HOST=128c-2601-583-701-b790-45b7-647b-44bb-5887.ngrok.io bin/rails server -p 3300

WEBHOOKS_HOST=128c-2601-583-701-b790-45b7-647b-44bb-5887.ngrok.io bin/rails console
```

**NOTE** Rails 7 uses [ActionDispatch::HostAuthorization](https://api.rubyonrails.org/classes/ActionDispatch/HostAuthorization.html) middleware to guard against attacks.  So we need to add the following

```ruby
# config/environments/development.rb

config.host_authorization = {
  exclude: ->(request) {
    request.url =~ /healthcheck|ngrok\.io/
  }
}
```


#### Broadcasting Webhook Events

In a new terminal, start up sidekiq:
```bash
sidekiq
```

NOTE: To clear jobs from sidekiq, in the rails console (not recommended to run in production):

```ruby
Sidekiq.redis(&:flushdb)
```


To broadcast a webhook event, in a rails console
```ruby
BroadcastWebhook.call(event: 'events.test', payload: { test: 2 })
```


#### Subscribing to Events

Webhook subscribers can subscribe to specific events.  By default subscribers are subscribe to all `['*']` events.

```ruby
[1] pry(main)> WebhookSubscriber.last.subscriptions
=> ["*"]

[2] pry(main)> WebhookSubscriber.last.subscribed?('events.noop')
=> true

[3] pry(main)> WebhookSubscriber.last.subscribed?('events.test')
=> true

[4] pry(main)> WebhookSubscriber.last.update!(subscriptions: ['events.test'])
=> true

[5] pry(main)> WebhookSubscriber.last.subscribed?('events.noop')
=> false

[6] pry(main)> WebhookSubscriber.last.subscribed?('events.test')
=> true

[7] pry(main)> WebhookSubscriber.last.subscriptions
=> ["events.test"]
```


#### Retry Algorithm

In the `WebhookWorker` we'll setup the following retry scheme:

```ruby
  MAX_RETRIES = 10

  # Set the max number of retries and tell sidekiq not to store failed webhooks
  # in its set of 'dead' jobs. We don't care about dead webhook jobs.
  sidekiq_options retry: MAX_RETRIES, dead: false

  sidekiq_retry_in do |retry_count|
    # Exponential backoff, with a random 30-second to 10-minute 'jitter'
    # added in to help spread out any webhook bursts.
    jitter = rand(30.seconds..10.minutes).to_i

    # Sidekiq's default retry cadence is retry_count ** 4
    (retry_count ** 5) + jitter
  end
```

Here we've set the maximum number of retries to 10, and we've also told Sidekiq to not store these failed webhooks in its set of "dead" jobs. We don't care about dead webhook jobs. With our retry exponent of 5 and a maximum retry limit of 10, retries should occur over approximately 3 days:


```ruby
[1] pry(main)> include ActionView::Helpers::DateHelper
=> Object

[2] pry(main)> total = 0.0
=> 0.0

[3] pry(main)> 10.times { |i| total += ((i + 1) ** 5) + rand(30.seconds..10.minutes) }
=> 10

[4] pry(main)> distance_of_time_in_words(total)
=> "3 days"
```



