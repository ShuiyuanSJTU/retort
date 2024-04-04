# frozen_string_literal: true
class DiscourseRetort::RetortsController < ::ApplicationController
  requires_plugin DiscourseRetort::PLUGIN_NAME
  before_action :verify_post_and_user, only: [:update, :remove]

  def update
    params.require(:retort)
    emoji = params[:retort]
    if !Emoji.exists?(emoji)
      respond_with_unprocessable(I18n.t("retort.error.missing_emoji"))
      return
    end

    disabled_emojis = SiteSetting.retort_disabled_emojis.split("|")
    if disabled_emojis.include?(emoji)
      respond_with_unprocessable(I18n.t("retort.error.disabled_emojis"))
      return
    end

    exist_record = Retort.find_by(post_id: post.id, user_id: current_user.id, emoji: emoji)
    if exist_record
      if exist_record.deleted?
        # Record has been deleted, try to create again
        if exist_record.can_recover?
          exist_record.recover!
          DiscourseEvent.trigger(:create_retort,post,current_user,emoji)
        else
          respond_with_unprocessable(I18n.t("retort.error.guardian_fail"))
          return
        end
      else
        if exist_record.can_withdraw?
          exist_record.withdraw!
          DiscourseEvent.trigger(:withdraw_retort,post,current_user,emoji)
        else
          respond_with_unprocessable(I18n.t("retort.error.exceed_withdraw_limit"))
          return
        end
      end
    else
      if !Retort.can_create?(current_user,post,emoji)
        respond_with_unprocessable(I18n.t("retort.error.guardian_fail"))
        return
      else
        begin
          exist_record = Retort.create(post_id: post.id, user_id: current_user.id, emoji: emoji)
          DiscourseEvent.trigger(:create_retort,post,current_user,emoji) unless exist_record.nil?
        rescue ActiveRecord::RecordNotUnique
          # Concurrent creation, ignore
        end
      end
    end

    MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}", serialized_post_retorts
    render json: { success: :ok }

  end

  def remove
    params.require(:retort)
    emoji = params[:retort]
    if !(current_user.staff? || current_user.trust_level == 4)
      respond_with_unprocessable(I18n.t("retort.error.guardian_fail"))
      return
    end

    result = Retort.remove_retort(post.id, emoji, current_user.id)
    if result
      UserHistory.create!(
        acting_user_id: current_user.id,
        action: UserHistory.actions[:post_edit],
        post_id: post.id,
        details: I18n.t("retort.log.remove", emoji: emoji)
      )
    end
    MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}", serialized_post_retorts
    render json: { success: :ok }
  end

  private

  def post
    @post ||= Post.find_by(id: params[:post_id]) if params[:post_id]
  end

  def verify_post_and_user
    respond_with_unprocessable(I18n.t("retort.error.missing_post", post_id: params[:post_id])) unless post
    respond_with_unprocessable(I18n.t("retort.error.guardian_fail")) unless current_user && !current_user.silenced?
    respond_with_unprocessable(I18n.t("retort.error.guardian_fail")) unless Guardian.new(current_user).can_see_post?(post)
    respond_with_unprocessable(I18n.t("retort.error.guardian_fail")) if SiteSetting.retort_disabled_categories.split("|").map(&:to_i).include?(post.topic.category_id)
    respond_with_unprocessable(I18n.t("retort.error.archived_topic")) if post.topic.archived?
  end

  def serialized_post_retorts
    ::PostSerializer.new(post.reload, scope: Guardian.new, root: false).as_json
  end

  def respond_with_unprocessable(error)
    render json: { error: error }, status: :unprocessable_entity
  end
end
