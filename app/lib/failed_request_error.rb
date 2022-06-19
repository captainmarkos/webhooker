# This is a general failed request error that is used to signal
# sidekiq to retry our webhook worker.
class FailedRequestError < StandardError; end
