# frozen_string_literal: true

# name: retort
# about: Reactions plugin for Discourse
# version: 1.2.4
# authors: Jiajun Du, pangbo. original: James Kiesel (gdpelican)
# url: https://github.com/ShuiyuanSJTU/retort

register_asset "stylesheets/common/retort.scss"
register_asset "stylesheets/mobile/retort.scss", :mobile
register_asset "stylesheets/desktop/retort.scss", :desktop

enabled_site_setting :retort_enabled

after_initialize do

  module ::DiscourseRetort
    PLUGIN_NAME ||= "retort".freeze

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseRetort
    end
  end

  require_relative "app/controllers/retorts_controller.rb"
  require_relative "app/models/retort.rb"

  DiscoursePluginRegistry.serialized_current_user_fields << 'hide_ignored_retorts'
  DiscoursePluginRegistry.serialized_current_user_fields << 'disable_retorts'

  User.register_custom_field_type 'hide_ignored_retorts', :boolean
  User.register_custom_field_type 'disable_retorts', :boolean

  register_editable_user_custom_field :hide_ignored_retorts
  register_editable_user_custom_field :disable_retorts

  DiscourseRetort::Engine.routes.draw do
    post "/:post_id" => "retorts#update"
    delete "/:post_id" => "retorts#remove"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseRetort::Engine, at: "/retorts"
  end

  require_dependency 'post_serializer'
  class ::PostSerializer
    attributes :retorts

    def retorts
      retort_groups = Retort.where(post_id: object.id, deleted_at: nil).includes(:user).order("created_at").group_by { |r| r.emoji }
      result = []
      retort_groups.each do |emoji, group|
        usernames = group.map { |retort| retort.user.username }
        result.push({ post_id: object.id, usernames: usernames, emoji: emoji })
      end
      result
    end
  end

  class ::User
    has_many :retorts, dependent: :destroy
  end

  class ::Post
    has_many :retorts, dependent: :destroy
  end

end
