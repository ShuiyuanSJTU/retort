# frozen_string_literal: true

require "rails_helper"
require "securerandom"

describe RetortsController do
  def unique_value(prefix)
    "#{prefix.to_s[0, 8]}#{SecureRandom.hex(3)}"
  end

  def create_user(prefix, fabricator = :user)
    token = unique_value(prefix)
    Fabricate(fabricator, username: token, email: "#{token}@example.com")
  end

  def create_category(prefix)
    token = unique_value(prefix)
    Fabricate(
      :category,
      user: create_user("catown"),
      name: "category-#{token}",
      slug: "category-#{token}",
    )
  end

  describe "as a regular user" do
    include ActiveSupport::Testing::TimeHelpers
    let(:user) { create_user("user") }
    let(:topic_owner) { create_user("topic-owner") }
    let(:disabled_category) { create_category("disabled") }
    let(:topic) do
      Fabricate(
        :topic,
        user: topic_owner,
        category: create_category("topic"),
        title: "Retort topic #{unique_value("title")}",
      )
    end
    let(:another_topic) do
      Fabricate(
        :topic,
        user: topic_owner,
        category: disabled_category,
        title: "Retort topic #{unique_value("alt")}",
      )
    end
    let(:first_post) do
      Fabricate(:post, topic: topic, user: topic_owner, raw: "first post #{unique_value("post")}")
    end
    let(:another_post) do
      Fabricate(
        :post,
        topic: another_topic,
        user: topic_owner,
        raw: "another post #{unique_value("post")}",
      )
    end

    context "when creating a retort" do
      before(:example) do
        SiteSetting.retort_disabled_emojis = "+1|laughing"
        SiteSetting.retort_disabled_categories = disabled_category.id.to_s
      end

      it "rejects requests from anonymous users" do
        put "/retorts/#{first_post.id}.json", params: { retort: "heart" }
        expect(response.status).to eq(403)
        expect(Retort.find_by(post_id: first_post.id, emoji: "heart")).to be_nil
      end

      it "rejects requests for a missing post" do
        sign_in(user)
        put "/retorts/100000.json", params: { retort: "heart" }
        expect(response.status).to eq(403)
      end

      it "creates a retort on an allowed post" do
        time = Time.new(2024, 12, 25, 01, 04, 44)
        travel_to time do
          sign_in(user)
          put "/retorts/#{first_post.id}.json", params: { retort: "heart" }
        end
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["id"]).to eq first_post.id
        new_retort = Retort.find_by(post_id: first_post.id, user_id: user.id, emoji: "heart")
        expect(new_retort).not_to be_nil
        expect(new_retort.created_at).to eq_time time
        expect(new_retort.updated_at).to eq_time time
        expect(new_retort.deleted_at).to be_nil
      end

      it "rejects posts in disabled categories" do
        sign_in(user)
        put "/retorts/#{another_post.id}.json", params: { retort: "heart" }
        expect(response.status).to eq(403)
      end

      it "rejects disabled emojis" do
        sign_in(user)
        put "/retorts/#{first_post.id}.json", params: { retort: "+1" }
        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)["errors"].first).to eq I18n.t(
             "retort.error.disabled_emojis",
           )
        put "/retorts/#{first_post.id}.json", params: { retort: "laughing" }
        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)["errors"].first).to eq I18n.t(
             "retort.error.disabled_emojis",
           )
      end

      it "rejects invalid emojis" do
        sign_in(user)
        put "/retorts/#{first_post.id}.json", params: { retort: "invalid__" }
        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)["errors"].first).to eq I18n.t("retort.error.missing_emoji")
      end

      it "rejects archived topics" do
        first_post.topic.update(archived: true)
        sign_in(user)
        put "/retorts/#{first_post.id}.json", params: { retort: "heart" }
        expect(response.status).to eq(403)
      end

      it "rejects silenced users" do
        user.update(silenced_till: 1.day.from_now)
        sign_in(user)
        put "/retorts/#{first_post.id}.json", params: { retort: "heart" }
        expect(response.status).to eq(403)
      end

      it "normalizes emoji aliases before saving" do
        sign_in(user)
        put "/retorts/#{first_post.id}.json", params: { retort: "xray" }
        expect(response.status).to eq(200)
        expect(
          Retort.find_by(post_id: first_post.id, user_id: user.id, emoji: "x_ray"),
        ).to be_present
      end

      it "normalizes aliased skin-tone emojis before saving" do
        sign_in(user)
        put "/retorts/#{first_post.id}.json", params: { retort: ":basketball_man:t4:" }
        expect(response.status).to eq(200)
        expect(
          Retort.find_by(post_id: first_post.id, user_id: user.id, emoji: "man_bouncing_ball:t4"),
        ).to be_present
      end
    end

    context "when withdrawing a retort" do
      let(:time) { Time.new(2024, 12, 25, 01, 04, 44) }
      let(:emoji) { "heart" }

      before(:example) do
        SiteSetting.retort_withdraw_tolerance = 10
        travel_to time do
          Retort.create(post_id: first_post.id, user_id: user.id, emoji: emoji)
        end
      end

      it "withdraws within the configured tolerance" do
        travel_to time + 1.seconds do
          sign_in(user)
          delete "/retorts/#{first_post.id}.json", params: { retort: emoji }
        end
        expect(JSON.parse(response.body)["id"]).to eq first_post.id
        retort = Retort.with_deleted.find_by(post_id: first_post.id, user_id: user.id, emoji: emoji)
        expect(retort.reload.deleted_at).to eq_time time + 1.seconds
        expect(retort.deleted_by).to eq user
        expect(retort.updated_at).to eq_time time + 1.seconds
        expect(retort.created_at).to eq_time time
      end

      it "rejects withdrawals after the tolerance window" do
        travel_to time + 11.seconds do
          sign_in(user)
          delete "/retorts/#{first_post.id}.json", params: { retort: emoji }
        end
        expect(response.status).to eq(403)
        retort = Retort.find_by(post_id: first_post.id, user_id: user.id, emoji: emoji)
        expect(retort.deleted_at).to be_nil
        expect(retort.deleted_by).to be_nil
      end
    end

    context "when recovering a retort" do
      let(:time) { Time.new(2024, 12, 25, 01, 04, 44) }
      let(:emoji) { "heart" }

      before(:example) do
        SiteSetting.retort_withdraw_tolerance = 10
        travel_to time do
          Retort.create(post_id: first_post.id, user_id: user.id, emoji: emoji).trash!(user)
        end
      end

      it "recovers a withdrawn retort" do
        travel_to time + 1.seconds do
          sign_in(user)
          put "/retorts/#{first_post.id}.json", params: { retort: emoji }
        end
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["id"]).to eq first_post.id
        retort = Retort.find_by(post_id: first_post.id, user_id: user.id, emoji: emoji)
        expect(retort.deleted_at).to be_nil
        expect(retort.deleted_by).to be_nil
        expect(retort.updated_at).to eq_time time + 1.seconds
        expect(retort.created_at).to eq_time time
      end

      it "allows recovery after the withdrawal tolerance expires" do
        travel_to time + 11.seconds do
          sign_in(user)
          put "/retorts/#{first_post.id}.json", params: { retort: emoji }
        end
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["id"]).to eq first_post.id
        retort = Retort.find_by(post_id: first_post.id, user_id: user.id, emoji: emoji)
        expect(retort.deleted_at).to be_nil
        expect(retort.deleted_by).to be_nil
        expect(retort.updated_at).to eq_time time + 11.seconds
        expect(retort.created_at).to eq_time time
      end
    end

    context "when withdrawing after recovery" do
      let(:time) { Time.new(2024, 12, 25, 01, 04, 44) }
      let(:emoji) { "heart" }

      before(:example) do
        SiteSetting.retort_withdraw_tolerance = 10
        travel_to time do
          Retort.create(post_id: first_post.id, user_id: user.id, emoji: emoji).trash!(user)
        end
        travel_to time + 6.seconds do
          Retort
            .with_deleted
            .find_by(post_id: first_post.id, user_id: user.id, emoji: emoji)
            .recover!
        end
      end

      it "allows withdrawal within the refreshed tolerance window" do
        travel_to time + 7.seconds do
          sign_in(user)
          delete "/retorts/#{first_post.id}.json", params: { retort: emoji }
        end
        expect(JSON.parse(response.body)["id"]).to eq first_post.id
        retort = Retort.with_deleted.find_by(post_id: first_post.id, user_id: user.id, emoji: emoji)
        expect(retort.deleted_at).to eq_time time + 7.seconds
        expect(retort.deleted_by).to eq user
        expect(retort.updated_at).to eq_time time + 7.seconds
        expect(retort.created_at).to eq_time time
      end

      it "resets the withdrawal tolerance after recovery" do
        travel_to time + 12.seconds do
          sign_in(user)
          delete "/retorts/#{first_post.id}.json", params: { retort: emoji }
        end
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["id"]).to eq first_post.id
        retort = Retort.with_deleted.find_by(post_id: first_post.id, user_id: user.id, emoji: emoji)
        expect(retort.deleted_at).to eq_time time + 12.seconds
        expect(retort.deleted_by).to eq user
        expect(retort.updated_at).to eq_time time + 12.seconds
        expect(retort.created_at).to eq_time time
      end

      it "rejects withdrawal after the refreshed tolerance window" do
        travel_to time + 17.seconds do
          sign_in(user)
          delete "/retorts/#{first_post.id}.json", params: { retort: emoji }
        end
        expect(response.status).to eq(403)
        retort = Retort.find_by(post_id: first_post.id, user_id: user.id, emoji: emoji)
        expect(retort.deleted_at).to be_nil
        expect(retort.deleted_by).to be_nil
        expect(retort.updated_at).to eq_time time + 6.seconds
        expect(retort.created_at).to eq_time time
      end
    end

    context "when removing all retorts for an emoji" do
      it "rejects non-staff bulk removal" do
        Retort.create(post_id: first_post.id, user_id: user.id, emoji: "heart")
        sign_in(user)
        delete "/retorts/#{first_post.id}/all.json", params: { retort: "heart" }
        expect(response.status).to eq(403)
        expect(
          Retort.find_by(post_id: first_post.id, user_id: user.id, emoji: "heart"),
        ).not_to be_nil
      end
    end
  end

  describe "as staff" do
    let(:staff) { create_user("staff", :moderator) }
    let(:post_owner) { create_user("postown") }
    let(:first_post) do
      topic =
        Fabricate(
          :topic,
          user: post_owner,
          category: create_category("staff"),
          title: "Retort topic #{unique_value("staff")}",
        )
      Fabricate(:post, topic: topic, user: post_owner, raw: "staff post #{unique_value("post")}")
    end
    let(:user) { create_user("user") }
    let(:another_user) { create_user("another") }

    context "when removing all retorts for an emoji" do
      let(:emoji) { "heart" }

      before(:example) do
        Retort.create(post_id: first_post.id, user_id: user.id, emoji: emoji)
        Retort.create(post_id: first_post.id, user_id: another_user.id, emoji: emoji)
      end

      it "removes all matching retorts" do
        sign_in(staff)
        delete "/retorts/#{first_post.id}/all.json", params: { retort: emoji }
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["id"]).to eq first_post.id
        expect(Retort.find_by(post_id: first_post.id, emoji: emoji, deleted_at: nil)).to be_nil
        expect(Retort.where(post_id: first_post.id, emoji: emoji).pluck(:deleted_by_id)).to all eq(
              staff.id,
            )
      end

      it "does not let other users recover a retort after staff removal" do
        Retort.find_by(post_id: first_post.id, user_id: user.id, emoji: emoji).trash!(user)
        sign_in(staff)
        delete "/retorts/#{first_post.id}/all.json", params: { retort: emoji }
        expect(response.status).to eq(200)
        sign_in(another_user)
        put "/retorts/#{first_post.id}.json", params: { retort: emoji }
        expect(response.status).to eq(403)
        sign_in(user)
        put "/retorts/#{first_post.id}.json", params: { retort: emoji }
        expect(response.status).to eq(200)
      end
    end
  end
end
