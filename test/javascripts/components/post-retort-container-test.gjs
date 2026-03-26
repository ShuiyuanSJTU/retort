import EmberObject from "@ember/object";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PostRetortContainer from "discourse/plugins/retort/discourse/components/post-retort-container";

function buildPost(overrides = {}) {
  return EmberObject.create({
    can_retort: true,
    can_remove_retort: false,
    my_retorts: [],
    retorts: [],
    topic: EmberObject.create({
      category: EmberObject.create({ id: 1 }),
    }),
    ...overrides,
  });
}

module("Retort | Component | post-retort-container", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.lookup("service:retort").siteSettings = this.siteSettings;
  });

  test("filters ignored users and invalid emoji entries before rendering sorted retorts", async function (assert) {
    this.currentUser.setProperties({
      ignored_users: ["ignored-a", "ignored-b"],
      custom_fields: { hide_ignored_retorts: true },
    });

    this.set(
      "post",
      buildPost({
        retorts: [
          { emoji: "smile", usernames: ["ignored-a", "alice"] },
          { emoji: "heart", usernames: ["bob", "ignored-b"] },
          { emoji: "laughing", usernames: ["ignored-a"] },
          { emoji: "invalid__", usernames: ["alice"] },
        ],
      })
    );

    await render(
      <template><PostRetortContainer @post={{this.post}} /></template>
    );

    assert
      .dom(".post-retort")
      .exists(
        { count: 2 },
        "the container renders only the retorts that still have visible users and valid emoji assets"
      );
    assert.deepEqual(
      Array.from(document.querySelectorAll(".post-retort img.emoji")).map(
        (image) => image.alt
      ),
      [":heart:", ":smile:"],
      "the remaining retorts stay sorted by emoji name after filtering"
    );
    assert
      .dom(".post-retort img[alt=':laughing:']")
      .doesNotExist(
        "retorts left with only ignored usernames are removed from the rendered list"
      );
    assert
      .dom(".post-retort img[alt=':invalid__:']")
      .doesNotExist(
        "retorts whose emoji cannot resolve to an image are not rendered"
      );
    assert.strictEqual(
      document
        .querySelector(".post-retort img[alt=':heart:']")
        .closest(".post-retort")
        .querySelector(".post-retort__count")
        .textContent.trim(),
      "1",
      "the heart retort count reflects only the non-ignored usernames"
    );
    assert.strictEqual(
      document
        .querySelector(".post-retort img[alt=':smile:']")
        .closest(".post-retort")
        .querySelector(".post-retort__count")
        .textContent.trim(),
      "1",
      "the smile retort keeps the remaining visible username after filtering"
    );
  });

  test("does not render the retort container for disabled topic categories", async function (assert) {
    this.siteSettings.retort_disabled_categories = "2|4";

    this.set(
      "post",
      buildPost({
        retorts: [{ emoji: "heart", usernames: ["alice"] }],
        topic: EmberObject.create({
          category: EmberObject.create({ id: 2 }),
        }),
      })
    );

    await render(
      <template><PostRetortContainer @post={{this.post}} /></template>
    );

    assert
      .dom(".post-retort-container")
      .doesNotExist(
        "the retort container stays hidden when the post topic category is disabled"
      );
  });
});
