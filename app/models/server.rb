class Server < ActiveRecord::Base
  has_many :backups

  # Keep these in order from highest to lowest frequency
  FREQUENCY_BUCKETS = ['minute', 'hourly', 'daily', 'weekly', 'monthly', 'quarterly', 'yearly']

  def is_active?
    state == 'active'
  end

  def is_highest_frequency_bucket?(tag)
    tag == get_highest_frequency_bucket
  end

  def get_highest_frequency_bucket
    FREQUENCY_BUCKETS.select{|frequency_bucket| respond_to?(frequency_bucket +'?') && send(frequency_bucket +'?')}.first
  end

  def get_number_allowed(frequency_bucket)
    respond_to?(frequency_bucket) ? send(frequency_bucket) : 0
  end

  def self.get_higher_frequency_buckets(frequency_bucket)
    return FREQUENCY_BUCKETS.slice(0, FREQUENCY_BUCKETS.index(frequency_bucket))
  end

  def self.get_interval_in_seconds(frequency_bucket)
    return case frequency_bucket
      when 'minute'     then 20.minutes
      when 'hourly'     then 1.hour
      when 'daily'      then 1.day
      when 'weekly'     then 1.week
      when 'monthly'    then 30.days
      when 'quarterly'  then 90.days
      when 'yearly'     then 1.year
    end
  end
end
