# frozen_string_literal: true

# mixin for all guardian methods dealing with retort permissions
module DiscourseRetort::RetortGuardian
  def can_create_retort?
    if SiteSetting.retort_disabled_users.split("|").include?(@user.username)
      return false
    end
    return false if @user.silenced?
    true
  end

  def can_create_retort_on_topic?(topic)
    return false if topic.archived?
    if SiteSetting
         .retort_disabled_categories
         .split("|")
         .map(&:to_i)
         .include?(topic.category_id)
      return false
    end
    true
  end

  def can_create_retort_on_post?(post)
    # discourse already checked `can_see?` at app/lib/guardian.rb#L192
    can_create_retort? && can_create_retort_on_topic?(post.topic)
  end

  def can_recover_retort?(retort)
    return false if retort.nil?
    return false unless is_my_own?(retort)
    return false unless can_create_retort_on_post?(retort.post)
    return false if @user.id != retort.deleted_by_id
    true
  end

  def can_withdraw_retort?(retort)
    return false if retort.nil?
    return false unless is_my_own?(retort)
    if retort.updated_at < SiteSetting.retort_withdraw_tolerance.second.ago
      return false
    end
    true
  end

  def can_moderate_retort?(post = nil)
    return false if post.nil?
    return true if is_staff?
    false
  end
end
