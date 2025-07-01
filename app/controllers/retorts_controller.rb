# frozen_string_literal: true
class RetortsController < ::ApplicationController
  requires_plugin DiscourseRetort::PLUGIN_NAME
  before_action :verify_post_and_user, only: %i[update remove create withdraw]
  before_action :normalize_emoji, only: %i[create update]

  rescue_from Discourse::InvalidParameters do |e|
    render_json_error e.message, status: 422
  end

  def create
    if !Emoji.exists?(emoji)
      raise Discourse::InvalidParameters.new I18n.t("retort.error.missing_emoji")
    end

    disabled_emojis = SiteSetting.retort_disabled_emojis.split("|")
    if disabled_emojis.include?(emoji)
      raise Discourse::InvalidParameters.new I18n.t("retort.error.disabled_emojis")
    end

    exist_record =
      Retort.with_deleted.find_by(post_id: post.id, user_id: current_user.id, emoji: emoji)
    if exist_record.present?
      if exist_record.trashed?
        # Record has been deleted, try to create again
        guardian.ensure_can_recover_retort!(exist_record)
        exist_record.recover!
        DiscourseEvent.trigger(:create_retort, post, current_user, emoji)
      end
    else
      guardian.ensure_can_create!(Retort, post)
      begin
        exist_record = Retort.create(post_id: post.id, user_id: current_user.id, emoji: emoji)
        DiscourseEvent.trigger(:create_retort, post, current_user, emoji) unless exist_record.nil?
      rescue ActiveRecord::RecordNotUnique
        # Concurrent creation, ignore
      end
    end
    MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}",
                       serialized_post_retorts_for_messagebus
    render json: serialized_post_retorts
  end

  def withdraw
    exist_record = Retort.find_by(post_id: post.id, user_id: current_user.id, emoji: emoji)
    if exist_record.present?
      guardian.ensure_can_withdraw_retort!(exist_record)
      exist_record.trash!(current_user)
      DiscourseEvent.trigger(:withdraw_retort, post, current_user, emoji)
    else
      raise Discourse::NotFound.new I18n.t("retort.error.not_found")
    end

    MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}",
                       serialized_post_retorts_for_messagebus
    render json: serialized_post_retorts
  end

  def update
    if !Emoji.exists?(emoji)
      raise Discourse::InvalidParameters.new I18n.t("retort.error.missing_emoji")
    end

    disabled_emojis = SiteSetting.retort_disabled_emojis.split("|")
    if disabled_emojis.include?(emoji)
      raise Discourse::InvalidParameters.new I18n.t("retort.error.disabled_emojis")
    end

    exist_record =
      Retort.with_deleted.find_by(post_id: post.id, user_id: current_user.id, emoji: emoji)
    if exist_record.present?
      if exist_record.trashed?
        # Record has been deleted, try to create again
        guardian.ensure_can_recover_retort!(exist_record)
        exist_record.recover!
        DiscourseEvent.trigger(:create_retort, post, current_user, emoji)
      else
        guardian.ensure_can_withdraw_retort!(exist_record)
        exist_record.trash!(current_user)
        DiscourseEvent.trigger(:withdraw_retort, post, current_user, emoji)
      end
    else
      guardian.ensure_can_create!(Retort, post)
      begin
        exist_record = Retort.create(post_id: post.id, user_id: current_user.id, emoji: emoji)
        DiscourseEvent.trigger(:create_retort, post, current_user, emoji) unless exist_record.nil?
      rescue ActiveRecord::RecordNotUnique
        # Concurrent creation, ignore
      end
    end

    MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}",
                       serialized_post_retorts_for_messagebus
    render json: serialized_post_retorts
  end

  def remove
    guardian.ensure_can_moderate_retort!(post)
    # Do not resolve emoji alias here, as we want to remove the exact retort
    emoji = params.require(:retort)

    result = Retort.remove_retort(post.id, emoji, current_user)
    if result.present?
      UserHistory.create!(
        acting_user_id: current_user.id,
        action: UserHistory.actions[:post_edit],
        post_id: post.id,
        details: I18n.t("retort.log.remove", emoji: emoji),
      )
    end
    MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}",
                       serialized_post_retorts_for_messagebus
    render json: serialized_post_retorts
  end

  private

  def normalize_emoji
    @normalized_emoji ||= Retort.normalize_emoji(params.require(:retort))
  end

  def emoji
    @normalized_emoji || params[:retort]
  end

  def post
    @post ||= Post.find_by(id: params[:post_id]) if params[:post_id]
  end

  def verify_post_and_user
    if !post.present? || !current_user.present?
      raise Discourse::InvalidAccess.new I18n.t("retort.error.guardian_fail")
    end
  end

  def serialized_post_retorts_for_messagebus
    {
      id: post.id,
      retorts: ::PostSerializer.new(post.reload, scope: Guardian.new, root: false).retorts,
    }
  end

  def serialized_post_retorts
    post_serializer =
      ::PostSerializer.new(post.reload, scope: Guardian.new(current_user), root: false)
    { id: post.id, retorts: post_serializer.retorts, my_retorts: post_serializer.my_retorts }
  end
end
