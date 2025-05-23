# frozen_string_literal: true

# name: retort
# about: Reactions plugin for Discourse
# version: 1.4.0
# authors: Jiajun Du, pangbo. original: James Kiesel (gdpelican)
# url: https://github.com/ShuiyuanSJTU/retort

register_asset "stylesheets/common/retort.scss"
register_asset "stylesheets/mobile/retort.scss", :mobile
register_asset "stylesheets/desktop/retort.scss", :desktop

enabled_site_setting :retort_enabled

after_initialize do
  module ::DiscourseRetort
    PLUGIN_NAME = "retort".freeze

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseRetort
    end
  end

  require_relative "app/controllers/retorts_controller.rb"
  require_relative "app/models/retort.rb"

  DiscoursePluginRegistry.serialized_current_user_fields << "hide_ignored_retorts"
  DiscoursePluginRegistry.serialized_current_user_fields << "disable_retorts"

  User.register_custom_field_type "hide_ignored_retorts", :boolean
  User.register_custom_field_type "disable_retorts", :boolean

  register_editable_user_custom_field :hide_ignored_retorts
  register_editable_user_custom_field :disable_retorts

  require_relative "lib/guardian/retort_guardian.rb"
  ::Guardian.prepend DiscourseRetort::RetortGuardian

  require_relative "lib/override_post_serializer.rb"
  ::PostSerializer.prepend DiscourseRetort::OverridePostSerializer

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

  DiscourseRetort::Engine.routes.draw do
    put "/:post_id" => "retorts#create"
    delete "/:post_id" => "retorts#withdraw"
    delete "/:post_id/all" => "retorts#remove"
  end

  Discourse::Application.routes.append { mount ::DiscourseRetort::Engine, at: "/retorts" }

  module DiscourseRetort::OverrideUser
    def self.included(klass)
      klass.has_many :retorts, dependent: :destroy
    end
  end
  ::User.include(DiscourseRetort::OverrideUser)

  module DiscourseRetort::OverridePost
    def self.included(klass)
      klass.has_many :retorts, dependent: :destroy
    end
  end
  ::Post.include(DiscourseRetort::OverridePost)

  class ::Chat::ChatController
    before_action :check_react, only: [:react]

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

  module DiscourseRetort::OverrideTopicView
    def initialize(topic_or_topic_id, user = nil, options = {})
      super
      @posts = @posts.includes(:retorts).includes(retorts: :user)
    end
  end

  TopicView.prepend(DiscourseRetort::OverrideTopicView)
end
