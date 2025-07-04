# frozen_string_literal: true

require "rails_helper"

describe RetortsController do
  describe "normal user" do
    include ActiveSupport::Testing::TimeHelpers
    let(:user) { Fabricate(:user) }
    let(:disabled_category) { Fabricate :category }
    let(:topic) { Fabricate :topic, category: Fabricate(:category) }
    let(:another_topic) { Fabricate :topic, category: disabled_category }
    let(:first_post) { Fabricate :post, topic: topic }
    let(:another_post) { Fabricate :post, topic: another_topic }

    context "when create retort" do
      before(:example) do
        SiteSetting.retort_disabled_emojis = "+1|laughing"
        SiteSetting.retort_disabled_categories = disabled_category.id.to_s
      end

      it "can not create without sign in" do
        put "/retorts/#{first_post.id}.json", params: { retort: "heart" }
        expect(response.status).to eq(403)
        expect(Retort.find_by(post_id: first_post.id, emoji: "heart")).to be_nil
      end

      it "can not create on invalid post" do
        sign_in(user)
        put "/retorts/100000.json", params: { retort: "heart" }
        expect(response.status).to eq(403)
      end

      it "can create on normal post" do
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

      it "can not create on disabled category post" do
        sign_in(user)
        put "/retorts/#{another_post.id}.json", params: { retort: "heart" }
        expect(response.status).to eq(403)
      end

      it "can not create on disabled emoji" do
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

      it "can not create invalid emoji" do
        sign_in(user)
        put "/retorts/#{first_post.id}.json", params: { retort: "invalid__" }
        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)["errors"].first).to eq I18n.t("retort.error.missing_emoji")
      end

      it "can not create on archived post" do
        first_post.topic.update(archived: true)
        sign_in(user)
        put "/retorts/#{first_post.id}.json", params: { retort: "heart" }
        expect(response.status).to eq(403)
      end

      it "can not create by silenced user" do
        user.update(silenced_till: 1.day.from_now)
        sign_in(user)
        put "/retorts/#{first_post.id}.json", params: { retort: "heart" }
        expect(response.status).to eq(403)
      end

      it "can resolve alias emoji" do
        sign_in(user)
        put "/retorts/#{first_post.id}.json", params: { retort: "xray" }
        expect(response.status).to eq(200)
        expect(
          Retort.find_by(post_id: first_post.id, user_id: user.id, emoji: "x_ray"),
        ).to be_present
      end
    end

    context "when withdraw retort" do
      let(:time) { Time.new(2024, 12, 25, 01, 04, 44) }
      let(:emoji) { "heart" }

      before(:example) do
        SiteSetting.retort_withdraw_tolerance = 10
        travel_to time do
          Retort.create(post_id: first_post.id, user_id: user.id, emoji: emoji)
        end
      end

      it "can withdraw within tolerance" do
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

      it "can not withdraw exceed tolerance" do
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

    context "when recover retort" do
      let(:time) { Time.new(2024, 12, 25, 01, 04, 44) }
      let(:emoji) { "heart" }

      before(:example) do
        SiteSetting.retort_withdraw_tolerance = 10
        travel_to time do
          Retort.create(post_id: first_post.id, user_id: user.id, emoji: emoji).trash!(user)
        end
      end

      it "can recover" do
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

      it "can recover even if exceed tolerance" do
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

    context "when withdraw after recover" do
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

      it "can withdraw within tolerance" do
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

      it "can withdraw as tolerance is counted from last recovery" do
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

      it "can not withdraw exceed tolerance" do
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

    context "when remove retort" do
      it "can not remove" do
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

  describe "staff user" do
    let(:staff) { Fabricate(:moderator) }
    let(:first_post) { Fabricate(:post) }
    let(:user) { Fabricate(:user) }
    let(:another_user) { Fabricate(:user) }

    context "when remove retort" do
      let(:emoji) { "heart" }

      before(:example) do
        Retort.create(post_id: first_post.id, user_id: user.id, emoji: emoji)
        Retort.create(post_id: first_post.id, user_id: another_user.id, emoji: emoji)
      end

      it "can remove" do
        sign_in(staff)
        delete "/retorts/#{first_post.id}/all.json", params: { retort: emoji }
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)["id"]).to eq first_post.id
        expect(Retort.find_by(post_id: first_post.id, emoji: emoji, deleted_at: nil)).to be_nil
        expect(Retort.where(post_id: first_post.id, emoji: emoji).pluck(:deleted_by_id)).to all eq(
              staff.id,
            )
      end

      it "can not recover after removed by staff" do
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
