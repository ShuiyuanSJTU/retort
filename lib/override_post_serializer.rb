module DiscourseRetort
  module OverridePostSerializer
    extend ::ActiveSupport::Concern
    
    prepended do
      attributes :retorts, :my_retorts, :can_retort
    end

    def retorts
      Discourse.cache.fetch(Retort.cache_key(object.id), expires_in: 5.minute) do
        retort_groups = Retort.where(post_id: object.id, deleted_at: nil).includes(:user).order("created_at").group_by { |r| r.emoji }
        result = []
        retort_groups.each do |emoji, group|
          usernames = group.map { |retort| retort.user.username }
          result.push({ post_id: object.id, usernames: usernames, emoji: emoji })
        end
        result
      end
    end

    def my_retorts
      return [] unless scope.user
      Retort.where(post_id: object.id, user_id: scope.user.id, deleted_at: nil)\
        .select(:emoji, :updated_at).map  { |result| result.attributes.compact }
    end

    def can_retort
      scope.can_create?(Retort, object)
    end
  end
end