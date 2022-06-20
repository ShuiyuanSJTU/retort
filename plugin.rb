# name: retort
# about: Reactions plugin for Discourse
# version: 1.2.3
# authors: Jiajun Du. original: James Kiesel (gdpelican)
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

  DiscourseRetort::Engine.routes.draw do
    post "/:post_id" => "retorts#update"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseRetort::Engine, at: "/retorts"
  end

  require_dependency 'post_serializer'
  class ::PostSerializer
    attributes :retorts

    def retorts
      retorts = Retort.where(post_id: object.id).includes(:user)
      emojis = Hash.new
      retorts.map do |retort|
        emojis[retort.emoji] ||= []
        emojis[retort.emoji].push(retort.user.username)
      end
      result = []
      emojis.each do |key, value|
        result.push({ post_id: object.id, usernames: value, emoji: key })
      end
      result
    end
  end

end
