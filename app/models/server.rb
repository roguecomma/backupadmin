class Server < ActiveRecord::Base
  has_many :backups

  # Keep these in order from highest to lowest frequency
  FREQUENCY_BUCKETS = ['minute', 'hourly', 'daily', 'weekly', 'monthly', 'quarterly', 'yearly']

  def is_active?
    state? && state == 'active'
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
      when 'minute' then (20 * 60)
      when 'hourly' then (60 * 60)
      when 'daily' then (24 * 60 * 60)
      when 'weekly' then (7 * 24 * 60 * 60)
      when 'monthly' then (31 * 24 * 60 * 60)
      when 'quarterly' then (90 * 24 * 60 * 60)
      when 'yearly' then (365 * 24 * 60 * 60)
    end
  end
end
