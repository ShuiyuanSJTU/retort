# frozen_string_literal: true

# name: retort
# about: Reactions plugin for Discourse
# version: 1.5.0
# authors: Jiajun Du, pangbo. original: James Kiesel (gdpelican)
# url: https://github.com/ShuiyuanSJTU/retort

register_asset "stylesheets/common/retort.scss"
register_asset "stylesheets/mobile/retort.scss", :mobile
register_asset "stylesheets/desktop/retort.scss", :desktop

enabled_site_setting :retort_enabled

module ::DiscourseRetort
  PLUGIN_NAME = "retort".freeze
end

Rails.autoloaders.main.push_dir(File.join(__dir__, "lib"), namespace: ::DiscourseRetort)

require_relative "lib/engine"

after_initialize do
  reloadable_patch do
    DiscoursePluginRegistry.serialized_current_user_fields << "hide_ignored_retorts"
    DiscoursePluginRegistry.serialized_current_user_fields << "disable_retorts"

    User.register_custom_field_type "hide_ignored_retorts", :boolean
    User.register_custom_field_type "disable_retorts", :boolean

    register_editable_user_custom_field :hide_ignored_retorts
    register_editable_user_custom_field :disable_retorts
  end

  reloadable_patch do
    ::Guardian.prepend DiscourseRetort::RetortGuardian
    ::PostSerializer.prepend DiscourseRetort::OverridePostSerializer
    ::User.include(DiscourseRetort::OverrideUser)
    ::Post.include(DiscourseRetort::OverridePost)
    ::TopicView.prepend(DiscourseRetort::OverrideTopicView)
    ::Chat::ChatController.include(DiscourseRetort::OverrideChatController)
  end

  register_stat("retort", expose_via_api: true) do
    {
      :last_day => Retort.where("created_at > ?", 1.days.ago).count,
      "7_days" => Retort.where("created_at > ?", 7.days.ago).count,
      "30_days" => Retort.where("created_at > ?", 30.days.ago).count,
      :previous_30_days =>
        Retort.where("created_at BETWEEN ? AND ?", 60.days.ago, 30.days.ago).count,
      :count => Retort.count,
    }
  end
end

module ::DiscourseRetort
  module OverrideUser
    def self.included(klass)
      klass.has_many :retorts, dependent: :destroy
    end
  end

  module OverridePost
    def self.included(klass)
      klass.has_many :retorts, dependent: :destroy
    end
  end

  module OverrideTopicView
    # For performance, we preload retorts and their users in the TopicView.
    def initialize(topic_or_topic_id, user = nil, options = {})
      super
      @posts = @posts.includes(:retorts).includes(retorts: :user)
    end
  end

  module OverrideChatController
    def self.included(klass)
      klass.before_action :check_react, only: [:react]
    end

    def check_react
      params.require(%i[emoji])

      disabled_emojis = SiteSetting.retort_chat_disabled_emojis.split("|")
      if disabled_emojis.include?(params[:emoji])
        render json: {
                 error: I18n.t("retort.error.disabled_emojis"),
               },
               status: :unprocessable_entity
      end
    end
  end
end
