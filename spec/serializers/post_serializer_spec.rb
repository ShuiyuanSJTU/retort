# frozen_string_literal: true

RSpec.describe PostSerializer do
  let(:post) { Fabricate(:post) }
  let(:user1) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }

  before(:example) do
    Retort.create(post_id: post.id, user_id: user1.id, emoji: "heart")
    Retort.create(post_id: post.id, user_id: user2.id, emoji: "heart")
    Retort.create(post_id: post.id, user_id: user1.id, emoji: "+1")
  end

  describe "serialize post" do
    it "should add retort" do
      post_serializer = PostSerializer.new(post, scope: Guardian.new).as_json[:post]
      expect(post_serializer[:retorts].length).to eq(2)
      expect(post_serializer[:retorts][0][:emoji]).to eq("heart")
      expect(post_serializer[:retorts][0][:usernames]).to eq([user1.username, user2.username])
      expect(post_serializer[:retorts][1][:emoji]).to eq("+1")
      expect(post_serializer[:retorts][1][:usernames]).to eq([user1.username])
    end

    it "should use cache" do
      Discourse.cache.expects(:fetch).twice
      post_serializer = PostSerializer.new(post, scope: Guardian.new).as_json
      Retort.expects(:where).never
      PostSerializer.new(post, scope: Guardian.new).as_json
    end
  end
end
