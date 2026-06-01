# frozen_string_literal: true

describe "retort:normalize_emojis" do
  before do
    Rake::Task.clear
    silence_warnings { Discourse::Application.load_tasks }
  end

  let(:user) { Fabricate(:user) }
  let(:another_user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }

  let(:topic_id) do
    timestamp = Time.zone.now
    attributes = {
      title: "Retort task topic",
      category_id: category.id,
      user_id: user.id,
      last_post_user_id: user.id,
      created_at: timestamp,
      updated_at: timestamp,
      bumped_at: timestamp,
    }

    Topic.insert!(attributes).rows[0][0]
  end

  let(:post_id) do
    timestamp = Time.zone.now
    attributes = {
      topic_id: topic_id,
      user_id: user.id,
      post_number: 1,
      raw: "Retort task post",
      cooked: "Retort task post",
      created_at: timestamp,
      updated_at: timestamp,
      last_version_at: timestamp,
    }

    Post.insert!(attributes).rows[0][0]
  end

  it "normalizes aliases and reports invalid emojis" do
    insert_retort(user: user, emoji: "xray")
    insert_retort(user: another_user, emoji: "xray")
    insert_retort(user: user, emoji: "x_ray")
    insert_retort(user: user, emoji: "invalid__")
    insert_retort(user: user, emoji: "")
    insert_retort(user: user, emoji: nil)
    insert_retort(user: user, emoji: "heart")

    output = capture_stdout { Rake::Task["retort:normalize_emojis"].invoke }

    expect(Retort.where(emoji: "xray")).to be_empty
    expect(Retort.where(post_id: post_id, emoji: "x_ray").pluck(:user_id)).to contain_exactly(
      user.id,
      another_user.id,
    )
    expect(Retort.find_by(post_id: post_id, user_id: user.id, emoji: "heart")).to be_present
    expect(Retort.find_by(post_id: post_id, user_id: user.id, emoji: "invalid__")).to be_present
    expect(Retort.find_by(post_id: post_id, user_id: user.id, emoji: "")).to be_present
    expect(Retort.find_by(post_id: post_id, user_id: user.id, emoji: nil)).to be_present

    invalid_line = output.lines.find { |line| line.start_with?("Found 3 invalid emojis:") }
    expect(invalid_line).to include("nil", '""', '"invalid__"')
  end

  def insert_retort(user:, emoji:)
    timestamp = Time.zone.now
    attributes = {
      post_id: post_id,
      user_id: user.id,
      emoji: emoji,
      created_at: timestamp,
      updated_at: timestamp,
    }

    Retort.insert!(attributes)
  end
end
