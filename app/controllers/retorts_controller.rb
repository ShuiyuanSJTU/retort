class DiscourseRetort::RetortsController < ::ApplicationController
  requires_plugin DiscourseRetort::PLUGIN_NAME
  before_action :verify_post_and_user, only: [:update, :delete]

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
      if !exist_record.can_toggle(current_user)
        respond_with_unprocessable(I18n.t("retort.error.exceed_withdraw_limit"))
        return
      end
      exist_record.toggle(current_user.id)
    else
      exist_record = Retort.create(post_id: post.id, user_id: current_user.id, emoji: emoji)
    end

    MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}", serialized_post_retorts
    render json: { success: :ok }
 
  end

  def remove
    params.require(:retort)
    emoji = params[:retort]
    if !(current_user.staff? || current_user.trust_level == 4)
      respond_with_unprocessable(I18n.t("retort.error.guardian_fail"))
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
  end

  def serialized_post_retorts
    ::PostSerializer.new(post.reload, scope: Guardian.new, root: false).as_json
  end

  def respond_with_unprocessable(error)
    render json: { error: error }, status: :unprocessable_entity
  end
end
