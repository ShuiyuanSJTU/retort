# frozen_string_literal: true

require_dependency 'rate_limiter'

class Retort < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
  validates :emoji, presence: true

  after_save :clear_cache
  after_destroy :clear_cache

  def deleted?
    return !self.deleted_at.nil?
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

  def can_recover?
    # If it cannot be created, it must not be recoverd
    return false if !Retort.can_create?(self.user,self.post,self.emoji)
    return true if self.user.staff? || self.user.trust_level == 4
    # withdrawn by self, can be recoverd
    return true if self.deleted_at && self.deleted_by == self.user.id
    false
  end

  def can_withdraw?
    return true if self.user.staff? || self.user.trust_level == 4
    return true if self.updated_at > SiteSetting.retort_withdraw_tolerance.second.ago
    false
  end

  def can_toggle?
    return false if self.deleted_at and !Retort.can_create?(user,self.post,self.emoji)
    # staff can do anything
    return true if self.user.staff? || self.user.trust_level == 4
    # deleted retort can be recovered
    return true if self.deleted_at && self.deleted_by != user.id
    # cannot delete old retort
    self.updated_at > SiteSetting.retort_withdraw_tolerance.second.ago
  end

  def self.can_create?(user,post,emoji)
    return false if user.silenced? || SiteSetting.retort_disabled_users.split("|").include?(user.username)
    return false if SiteSetting.retort_disabled_emojis.split("|").include?(emoji)
    return true if user.staff? || user.trust_level == 4
    return false if post.topic.archived?
    true
  end

  def self.remove_retort(post_id, emoji, actor_id)
    exist_record = Retort.where(post_id: post_id, emoji: emoji)
    if exist_record
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
    return 1.0 unless user&.trust_level.to_i >= 2
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

  def self.serialize_for_post(post)
    Discourse.cache.fetch(Retort.cache_key(post.id), expires_in: 5.minute) do
      retort_groups = Retort.where(post_id: post.id, deleted_at: nil).includes(:user).order("created_at").group_by { |r| r.emoji }
      result = []
      retort_groups.each do |emoji, group|
        usernames = group.map { |retort| retort.user.username }
        result.push({ post_id: post.id, usernames: usernames, emoji: emoji })
      end
      result
    end
  end
end
