class CLogger
  def initialize(tag='Clogger.log')
    @tag = tag
  end

  def log_activity(message, type=nil)
    Rails.logger.tagged(@tag) do
      type == :error ? Rails.logger.error(message) : Rails.logger.info(message)
    end
  end
end
