# frozen_string_literal: true

require_dependency "rate_limiter"

class Retort < ActiveRecord::Base
  include Trashable

  belongs_to :post
  belongs_to :user
  validates :emoji, presence: true

  after_save :clear_cache
  after_destroy :clear_cache

  def trash_update(deleted_at, deleted_by_id)
    # override trash_update to trigger callbacks and set updated_at
    self.deleted_at = deleted_at
    self.deleted_by_id = deleted_by_id
    self.updated_at = deleted_at.present? ? deleted_at : Time.now
    self.save!
  end

  def toggle!
    self.trashed? ? self.recover! : self.trash!(user)
  end

  def self.remove_retort(post_id, emoji, actor)
    exist_record = Retort.where(post_id: post_id, emoji: emoji)
    if exist_record.present?
      exist_record.update_all(deleted_at: Time.now, updated_at: Time.now, deleted_by_id: actor.id)
      Retort.clear_cache(post_id)
      return true
    end
    false
  end

  include RateLimiter::OnCreateRecord
  rate_limit :retort_rate_limiter
  def retort_rate_limiter
    @rate_limiter ||=
      RateLimiter.new(user, "create_retort", retort_max_per_day, 1.day.to_i)
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

# == Schema Information
#
# Table name: retorts
#
#  id         :bigint           not null, primary key
#  emoji      :string
#  post_id    :integer
#  user_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  deleted_at :datetime
#  deleted_by :integer
#
# Indexes
#
#  index_retorts_on_emoji                          (emoji)
#  index_retorts_on_post_id                        (post_id)
#  index_retorts_on_post_id_and_user_id_and_emoji  (post_id,user_id,emoji) UNIQUE
#  index_retorts_on_user_id                        (user_id)
#  retorts_post_id_idx                             (post_id)
#
# Foreign Keys
#
#  fk_rails_...  (post_id => posts.id)
#  fk_rails_...  (user_id => users.id)
#
