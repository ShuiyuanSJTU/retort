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

  describe "#retorts" do
    it "should add retort" do
      post_serializer =
        PostSerializer.new(post, scope: Guardian.new).as_json[:post]
      expect(post_serializer[:retorts].length).to eq(2)
      expect(post_serializer[:retorts][0][:emoji]).to eq("heart")
      expect(post_serializer[:retorts][0][:usernames]).to eq(
        [user1.username, user2.username]
      )
      expect(post_serializer[:retorts][1][:emoji]).to eq("+1")
      expect(post_serializer[:retorts][1][:usernames]).to eq([user1.username])
    end

    it "should use cache" do
      PostSerializer.new(post, scope: Guardian.new).as_json
      Retort.expects(:where).never
      PostSerializer.new(post, scope: Guardian.new).as_json
    end
  end

  describe "#my_retorts" do
    it "should add my retorts" do
      post_serializer =
        PostSerializer.new(post, scope: Guardian.new(user1)).as_json[:post]
      expect(post_serializer[:my_retorts].length).to eq(2)
      expect(post_serializer[:my_retorts].pluck(:emoji)).to match_array(
        %w[heart +1]
      )
      expect(
        post_serializer[:my_retorts].pluck(:updated_at).compact.length
      ).to eq(2)
    end

    it "should be empty for anonymous" do
      post_serializer =
        PostSerializer.new(post, scope: Guardian.new).as_json[:post]
      expect(post_serializer[:my_retorts]).to eq([])
    end
  end

  describe "#can_retort" do
    it "should be true for normal user" do
      expect(
        PostSerializer.new(post, scope: Guardian.new(user1)).as_json[:post][
          :can_retort
        ]
      ).to eq(true)
    end

    it "should be false for anonymous" do
      expect(
        PostSerializer.new(post, scope: Guardian.new).as_json[:post][
          :can_retort
        ]
      ).to eq(false)
    end
  end

  describe "#can_remove_retort" do
    it "should be false for normal user" do
      expect(
        PostSerializer.new(post, scope: Guardian.new(user1)).as_json[:post][
          :can_remove_retort
        ]
      ).to eq(false)
    end

    it "should be true for staff" do
      expect(
        PostSerializer.new(
          post,
          scope: Guardian.new(Fabricate(:admin))
        ).as_json[
          :post
        ][
          :can_remove_retort
        ]
      ).to eq(true)
    end
  end
end
