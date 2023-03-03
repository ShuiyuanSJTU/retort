# frozen_string_literal: true

require_dependency 'rate_limiter'

class Retort < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
  validates :emoji, presence: true
  validates_associated :post, :user, presence: true

  def deleted?
    return !self.deleted_at.nil?
  end

  def toggle!
    if self.deleted?
      self.recreate!
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

  def recreate!
    self.deleted_at = nil
    self.deleted_by = nil
    self.save!
  end

  def can_recreate?
    # If it cannot be created, it must not be recreated
    return false if !Retort.can_create?(self.user,self.post,self.emoji)
    return true if self.user.staff? || self.user.trust_level == 4
    # withdrawn by self, can be recreated
    return true if self.deleted_at && self.deleted_by == self.user.id
    false
  end

  def can_withdraw?
    return true if self.user.staff? || self.user.trust_level == 4
    return true self.updated_at > SiteSetting.retort_withdraw_tolerance.second.ago
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
end
