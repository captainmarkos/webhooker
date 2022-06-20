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


### Create the app and setup

```bash
rails new webhooker \
  --api \
  --database sqlite3 \
  --skip-active-storage \
  --skip-action-cable
```

### Turn off irb autocomplete in rails console

```bash
cat >> ~/.irbrc
IRB.conf[:USE_AUTOCOMPLETE] = false
```

```bash
bin/rails console --noautocomplete
```

```ruby
[1] pry(main)> pry-theme install vividchalk

[2] pry(main)> pry-theme try vividchalk

[3] pry(main)> s = WebhookSubscriber.create!(url: 'https://functions.ecorp.example/webhooks')

[4] pry(main)> e = WebhookEvent.create!(webhook_subscriber: s, name: 'events.test', payload: { test: 1 })

[5] pry(main)> WebhookWorker.new.perform(WebhookEvent.last.id)
```

#### Add some pry-themes from the [pry-theme gem](https://github.com/kyrylo/pry-theme).
```bash
cat >> .pryrc
Pry.config.theme = 'vividchalk'
#Pry.config.theme = 'tomorrow-night'
#Pry.config.theme = 'pry-modern-256'
#Pry.config.theme = 'ocean'
```







