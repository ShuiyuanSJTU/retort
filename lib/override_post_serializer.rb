# frozen_string_literal: true
module DiscourseRetort
  module OverridePostSerializer
    extend ::ActiveSupport::Concern

    prepended do
      attributes :retorts, :my_retorts, :can_retort, :can_remove_retort
    end

    def retorts
      Discourse
        .cache
        .fetch(Retort.cache_key(object.id), expires_in: 5.minute) do
          retort_groups =
            object.retorts
              .to_a
              .sort_by { |r| r.updated_at }
              .group_by { |r| r.emoji }
          result = []
          retort_groups.each do |emoji, group|
            usernames = group.map { |retort| retort.user.username }
            result.push(
              { post_id: object.id, usernames: usernames, emoji: emoji }
            )
          end
          result
        end
    end

    def my_retorts
      return [] unless scope.user
      object.retorts
        .filter { |r| r.user_id == scope.user.id }
        .map { |r| {emoji: r.emoji, updated_at: r.updated_at} }
    end

    def can_retort
      scope.can_create?(Retort, object)
    end

    def can_remove_retort
      scope.can_moderate_retort?(object)
    end
  end
end
