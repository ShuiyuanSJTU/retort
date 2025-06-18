# frozen_string_literal: true

DiscourseRetort::Engine.routes.draw do
  put "/:post_id" => "retorts#create"
  delete "/:post_id" => "retorts#withdraw"
  delete "/:post_id/all" => "retorts#remove"
end

Discourse::Application.routes.draw { mount ::DiscourseRetort::Engine, at: "/retorts" }
