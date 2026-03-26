# frozen_string_literal: true

require "rails_helper"
require "securerandom"

describe Retort do
  def unique_value(prefix)
    "#{prefix.to_s[0, 8]}#{SecureRandom.hex(3)}"
  end

  def create_user(prefix)
    token = unique_value(prefix)
    Fabricate(:user, username: token, email: "#{token}@example.com")
  end

  def create_topic(owner:)
    Fabricate(
      :topic,
      user: owner,
      category: Fabricate(:category, user: owner),
      title: "Retort topic #{unique_value("title")}",
    )
  end

  before(:example) {}

  let(:user) { create_user("user") }
  let(:topic_owner) { create_user("owner") }
  let(:topic) { create_topic(owner: topic_owner) }
  let(:post) do
    Fabricate(:post, topic: topic, user: topic_owner, raw: "retort post #{unique_value("post")}")
  end
  let(:another_post) do
    Fabricate(:post, topic: topic, user: topic_owner, raw: "retort post #{unique_value("post")}")
  end
  let(:another_topic_post) do
    another_owner = create_user("owner")
    another_topic = create_topic(owner: another_owner)
    Fabricate(
      :post,
      topic: another_topic,
      user: another_owner,
      raw: "retort post #{unique_value("post")}",
    )
  end
  let(:emoji) { "kickbutt" }
  let(:altermoji) { "puntrear" }

  describe "creation" do
    let(:retort) { Retort.create(post_id: post.id, user_id: user.id, emoji: emoji) }

    it "persists the associated post, user, and emoji" do
      expect(retort.post).to eq post
      expect(retort.user).to eq user
      expect(retort.emoji).to eq emoji
    end

    it "sets timestamps on creation" do
      expect(retort.created_at).not_to be_nil
      expect(retort.updated_at).not_to be_nil
      expect(retort.updated_at).to eq_time retort.created_at
    end

    it "starts in the active state" do
      expect(retort.deleted_at).to be_nil
      expect(retort.deleted_by).to be_nil
    end
  end

  describe "validations" do
    it "requires an emoji" do
      expect { Retort.create(post_id: post.id, user_id: user.id, emoji: nil).save! }.to raise_error(
        ActiveRecord::RecordInvalid,
      )
    end

    it "requires a valid post" do
      invalid_post_id = post.id + 100_000
      expect {
        Retort.create(post_id: invalid_post_id, user_id: user.id, emoji: emoji)
      }.to raise_error ActiveRecord::InvalidForeignKey
    end

    it "allows a valid retort" do
      expect { Retort.create(post_id: post.id, user_id: user.id, emoji: emoji) }.not_to raise_error
    end
  end

  describe "state transitions" do
    let(:retort) { Retort.create(post_id: post.id, user_id: user.id, emoji: emoji) }

    it "rejects duplicate retorts for the same post, user, and emoji" do
      expect(retort).not_to be_nil
      expect {
        Retort.create(post_id: post.id, user_id: user.id, emoji: emoji).save!
      }.to raise_error ActiveRecord::RecordNotUnique
    end

    it "soft-deletes the retort and records who withdrew it" do
      expect { retort.trash!(user) }.to change { retort.deleted_at }.from(nil).to(
        be_present,
      ).and change { retort.deleted_by }.from(nil).to(user)
    end

    it "recovers a deleted retort and clears deleted_by" do
      original_created_at = retort.created_at
      retort.trash!(user)
      expect { retort.recover! }.to change { retort.deleted_at }.from(be_present).to(
        nil,
      ).and change { retort.deleted_by }.from(user).to(nil)
      expect(retort.created_at).to eq_time original_created_at
      expect(retort.updated_at).not_to eq_time original_created_at
    end
  end

  describe ".normalize_emoji" do
    before(:example) { Emoji.clear_cache }
    after(:example) { Emoji.clear_cache }

    it "resolves aliases through Discourse's emoji lookup" do
      expect(Retort.normalize_emoji("xray")).to eq("x_ray")
      expect(Retort.normalize_emoji(":xray:")).to eq("x_ray")
    end

    it "resolves aliased skin-tone emoji to their canonical names" do
      expect(Retort.normalize_emoji("basketball_man:t4")).to eq("man_bouncing_ball:t4")
      expect(Retort.normalize_emoji(":basketball_man:t4:")).to eq("man_bouncing_ball:t4")
    end

    it "keeps custom emoji names that contain tone-like segments" do
      custom_name = "retort#{unique_value("cust")}:t1:foo"
      CustomEmoji.create!(name: custom_name, upload_id: 9999)
      Emoji.clear_cache

      expect(Retort.normalize_emoji(":#{custom_name}:")).to eq(custom_name)
    end
  end
end
