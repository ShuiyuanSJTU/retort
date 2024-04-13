# frozen_string_literal: true

require_dependency 'rate_limiter'

class Retort < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
  validates :emoji, presence: true

  after_save :clear_cache
  after_destroy :clear_cache

  def deleted?
    !self.deleted_at.nil?
  end

  def toggle!
    if self.deleted?
      self.recover!
    else
      self.withdraw!
    end
    self.save!
  end

  def withdraw!
    self.deleted_at = Time.now
    self.deleted_by = user.id
    self.save!
  end

  def recover!
    self.deleted_at = nil
    self.deleted_by = nil
    self.save!
  end

  def self.remove_retort(post_id, emoji, actor_id)
    exist_record = Retort.where(post_id: post_id, emoji: emoji)
    if exist_record.present?
      exist_record.update_all(deleted_at: Time.now, deleted_by: actor_id)
      Retort.clear_cache(post_id)
      return true
    end
    false
  end

  include RateLimiter::OnCreateRecord
  rate_limit :retort_rate_limiter
  def retort_rate_limiter
    @rate_limiter ||= RateLimiter.new(user, "create_retort", retort_max_per_day, 1.day.to_i)
  end

  def retort_max_per_day
    (SiteSetting.retort_max_per_day * retort_trust_multiplier).to_i
  end

  def retort_trust_multiplier
    return 1.0 if user&.trust_level.to_i < 2
      SiteSetting.send(:"retort_tl#{user.trust_level}_max_per_day_multiplier")
  end

  def self.cache_key(post_id)
    "retort-#{post_id}"
  end

  def clear_cache
    Retort.clear_cache(self.post_id)
  end

  def self.clear_cache(post_id)
    Discourse.cache.delete(Retort.cache_key(post_id))
  end
end
