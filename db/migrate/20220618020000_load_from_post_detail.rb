# frozen_string_literal: true
class LoadFromPostDetail < ActiveRecord::Migration[7.0]
  def change
    old_retorts = PostDetail.where(extra: "retort")
    old_retorts.each do |r|
      emoji = r.key.split("|").first
      user_ids = JSON.parse(r.value)
      data = user_ids.map { |id| { post_id: r.post_id, user_id: id, emoji: emoji } }
      Retort.insert_all(data)
    end
    old_retorts.destroy_all
  end
end
