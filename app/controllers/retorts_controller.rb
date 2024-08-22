# frozen_string_literal: true
class DiscourseRetort::RetortsController < ::ApplicationController
  requires_plugin DiscourseRetort::PLUGIN_NAME
  before_action :verify_post_and_user, only: %i[update remove create withdraw]

  def create
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

    exist_record =
      Retort.find_by(post_id: post.id, user_id: current_user.id, emoji: emoji)
    if exist_record.present?
      if exist_record.deleted?
        # Record has been deleted, try to create again
        guardian.ensure_can_recover_retort!(exist_record)
        exist_record.recover!
        DiscourseEvent.trigger(:create_retort, post, current_user, emoji)
      end
    else
      guardian.ensure_can_create!(Retort, post)
      begin
        exist_record =
          Retort.create(
            post_id: post.id,
            user_id: current_user.id,
            emoji: emoji
          )
        unless exist_record.nil?
          DiscourseEvent.trigger(:create_retort, post, current_user, emoji)
        end
      rescue ActiveRecord::RecordNotUnique
        # Concurrent creation, ignore
      end
    end
    MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}",
                       serialized_post_retorts_for_messagebus
    render json: serialized_post_retorts
  end

  def withdraw
    params.require(:retort)
    emoji = params[:retort]

    exist_record =
      Retort.find_by(post_id: post.id, user_id: current_user.id, emoji: emoji)
    if exist_record.present? && !exist_record.deleted?
      # Record has been deleted, try to create again
      guardian.ensure_can_withdraw_retort!(exist_record)
      exist_record.withdraw!
      DiscourseEvent.trigger(:withdraw_retort, post, current_user, emoji)
    else
      respond_with_unprocessable(I18n.t("retort.error.not_found"))
      return
    end

    MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}",
                       serialized_post_retorts_for_messagebus
    render json: serialized_post_retorts
  end

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

    exist_record =
      Retort.find_by(post_id: post.id, user_id: current_user.id, emoji: emoji)
    if exist_record.present?
      if exist_record.deleted?
        # Record has been deleted, try to create again
        guardian.ensure_can_recover_retort!(exist_record)
        exist_record.recover!
        DiscourseEvent.trigger(:create_retort, post, current_user, emoji)
      else
        guardian.ensure_can_withdraw_retort!(exist_record)
        exist_record.withdraw!
        DiscourseEvent.trigger(:withdraw_retort, post, current_user, emoji)
      end
    else
      guardian.ensure_can_create!(Retort, post)
      begin
        exist_record =
          Retort.create(
            post_id: post.id,
            user_id: current_user.id,
            emoji: emoji
          )
        unless exist_record.nil?
          DiscourseEvent.trigger(:create_retort, post, current_user, emoji)
        end
      rescue ActiveRecord::RecordNotUnique
        # Concurrent creation, ignore
      end
    end

    MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}",
                       serialized_post_retorts_for_messagebus
    render json: serialized_post_retorts
  end

  def remove
    params.require(:retort)
    emoji = params[:retort]
    guardian.ensure_can_moderate_retort!(post)

    result = Retort.remove_retort(post.id, emoji, current_user.id)
    if result.present?
      UserHistory.create!(
        acting_user_id: current_user.id,
        action: UserHistory.actions[:post_edit],
        post_id: post.id,
        details: I18n.t("retort.log.remove", emoji: emoji)
      )
    end
    MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}",
                       serialized_post_retorts_for_messagebus
    render json: serialized_post_retorts
  end

  private

  def post
    @post ||= Post.find_by(id: params[:post_id]) if params[:post_id]
  end

  def verify_post_and_user
    if !post.present? || !current_user.present?
      raise Discourse::InvalidAccess.new(I18n.t("retort.error.guardian_fail"))
    end
  end

  def serialized_post_retorts_for_messagebus
    {
      id: post.id,
      retorts:
        ::PostSerializer.new(
          post.reload,
          scope: Guardian.new,
          root: false
        ).retorts
    }
  end

  def serialized_post_retorts
    post_serializer = ::PostSerializer.new(
      post.reload,
      scope: Guardian.new(current_user),
      root: false
    )
    {
      id: post.id,
      retorts: post_serializer.retorts,
      my_retorts: post_serializer.my_retorts
    }
  end

  def respond_with_unprocessable(error)
    render json: { error: error }, status: :unprocessable_entity
  end
end
