import EmberObject from "@ember/object";
import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import RetortToggleButton from "discourse/plugins/retort/discourse/components/retort-toggle-button";

class MockRetortService extends Service {
  createCalls = [];
  withdrawCalls = [];

  createRetort(post, emoji) {
    this.createCalls.push({ post, emoji });
    return Promise.resolve({ retorts: [], my_retorts: [] });
  }

  withdrawRetort(post, emoji) {
    this.withdrawCalls.push({ post, emoji });
    return Promise.resolve({ retorts: [], my_retorts: [] });
  }
}

function buildPost(overrides = {}) {
  return EmberObject.create({
    id: 123,
    can_retort: true,
    can_remove_retort: false,
    my_retorts: [],
    ...overrides,
  });
}

module("Retort | Component | retort-toggle-button", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.register("service:retort", MockRetortService);
    this.retortService = this.owner.lookup("service:retort");
    this.currentUser.username = "pangbo";
    this.siteSettings.retort_withdraw_tolerance = 3600;
  });

  test("sends a create request when the current user has not reacted yet", async function (assert) {
    this.setProperties({
      post: buildPost(),
      usernames: ["alice"],
    });

    await render(
      <template>
        <RetortToggleButton
          @emoji="heart"
          @emojiUrl="/images/emoji/twitter/heart.png"
          @usernames={{this.usernames}}
          @post={{this.post}}
        />
      </template>
    );

    await click(".post-retort");

    assert.strictEqual(
      this.retortService.createCalls.length,
      1,
      "clicking a non-current-user retort sends one create request"
    );
    assert.strictEqual(
      this.retortService.withdrawCalls.length,
      0,
      "clicking a non-current-user retort does not send a withdraw request"
    );
    assert.strictEqual(
      this.retortService.createCalls[0].post.id,
      this.post.id,
      "the create request targets the clicked post"
    );
    assert.strictEqual(
      this.retortService.createCalls[0].emoji,
      "heart",
      "the create request uses the clicked emoji name"
    );
  });

  test("sends a withdraw request when the current user clicks their own active retort", async function (assert) {
    this.setProperties({
      post: buildPost({
        my_retorts: [{ emoji: "heart", updated_at: new Date().toISOString() }],
      }),
      usernames: ["pangbo", "alice"],
    });

    await render(
      <template>
        <RetortToggleButton
          @emoji="heart"
          @emojiUrl="/images/emoji/twitter/heart.png"
          @usernames={{this.usernames}}
          @post={{this.post}}
        />
      </template>
    );

    await click(".post-retort");

    assert.strictEqual(
      this.retortService.createCalls.length,
      0,
      "clicking the current user's active retort does not send a create request"
    );
    assert.strictEqual(
      this.retortService.withdrawCalls.length,
      1,
      "clicking the current user's active retort sends one withdraw request"
    );
    assert.strictEqual(
      this.retortService.withdrawCalls[0].post.id,
      this.post.id,
      "the withdraw request targets the clicked post"
    );
    assert.strictEqual(
      this.retortService.withdrawCalls[0].emoji,
      "heart",
      "the withdraw request uses the clicked emoji name"
    );
  });

  test("disables expired current-user retorts and blocks follow-up requests", async function (assert) {
    this.setProperties({
      post: buildPost({
        my_retorts: [
          { emoji: "heart", updated_at: "2021-06-08T21:59:16.444Z" },
        ],
      }),
      usernames: ["pangbo"],
    });

    await render(
      <template>
        <RetortToggleButton
          @emoji="heart"
          @emojiUrl="/images/emoji/twitter/heart.png"
          @usernames={{this.usernames}}
          @post={{this.post}}
        />
      </template>
    );

    assert
      .dom(".post-retort")
      .hasClass(
        "disabled",
        "a current-user retort past the withdraw tolerance renders as disabled"
      );

    await click(".post-retort");

    assert.strictEqual(
      this.retortService.createCalls.length,
      0,
      "clicking a disabled retort does not send a create request"
    );
    assert.strictEqual(
      this.retortService.withdrawCalls.length,
      0,
      "clicking a disabled retort does not send a withdraw request"
    );
  });
});
