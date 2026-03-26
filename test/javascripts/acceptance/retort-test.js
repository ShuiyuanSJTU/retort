import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  count,
  exists,
  publishToMessageBus,
  query,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import retortFixtures from "../fixtures/topic-with-retort";

acceptance("Retorts", function (needs) {
  needs.user({ username: "pangbo" });
  needs.settings({ retort_withdraw_tolerance: 3600 });

  needs.pretender((server, helper) => {
    server.get("/t/114514.json", () => {
      return helper.response(retortFixtures["/t/114514.json"]);
    });

    server.put("/retorts/398.json", () => {
      return helper.response(retortFixtures["put:/retorts/398.json"]);
    });

    server.put("/retorts/421.json", () =>
      helper.response(403, {
        errors: ["FAIL"],
      })
    );
  });

  test("renders enabled-post retorts with the expected current-user and withdraw states", async function (assert) {
    await visit("/t/retort-topic/114514");

    assert.strictEqual(
      count("#post_1 .post-retort-container button.post-retort"),
      4,
      "post 1 renders all four retort buttons from the server payload"
    );
    assert.strictEqual(
      count("#post_1 .post-retort-container button.post-retort.my-retort"),
      3,
      "post 1 marks the three current-user retorts with the my-retort class"
    );
    assert.true(
      visible("#post_1 .actions button.retort"),
      "post 1 shows the retort picker trigger when adding retorts is allowed"
    );
    assert.strictEqual(
      query(
        "#post_1 .post-retort-container button.post-retort.my-retort.disabled img"
      ).getAttribute("alt"),
      ":pouting_cat:",
      "post 1 keeps the expired current-user retort disabled"
    );
    assert.strictEqual(
      query(
        "#post_1 .post-retort-container button.post-retort.my-retort:not(.disabled) img"
      ).getAttribute("alt"),
      ":+1:",
      "post 1 keeps a withdrawable current-user retort enabled"
    );
  });

  test("renders retorts as fully disabled when the post cannot receive new retorts", async function (assert) {
    await visit("/t/retort-topic/114514");

    assert.strictEqual(
      count("#post_2 .post-retort-container button.post-retort"),
      3,
      "post 2 still renders the three existing retort buttons"
    );
    assert.strictEqual(
      count("#post_2 .post-retort-container button.post-retort.my-retort"),
      2,
      "post 2 still marks the two current-user retorts with the my-retort class"
    );
    assert.false(
      visible("#post_2 .actions button.retort"),
      "post 2 hides the retort picker trigger when retorts are disabled"
    );
    assert.strictEqual(
      count("#post_2 .post-retort-container button.post-retort.disabled img"),
      3,
      "post 2 renders every retort button in the disabled state"
    );
    assert.false(
      exists(
        "#post_2 .post-retort-container button.post-retort:not(.disabled) img"
      ),
      "post 2 does not leave any enabled retort buttons behind"
    );
  });

  test("shows remove controls when the current user can moderate retorts", async function (assert) {
    await visit("/t/retort-topic/114514");

    assert.strictEqual(
      count("#post_3 .post-retort-container button.post-retort .remove-retort"),
      3,
      "post 3 renders one remove control for each visible retort button"
    );
  });

  test("withdraws an active current-user retort instead of creating a new one", async function (assert) {
    const putEndpoint = sinon.spy();
    const deleteEndpoint = sinon.spy();
    await visit("/t/retort-topic/114514");
    assert.strictEqual(
      count("#post_1 .post-retort-container button.post-retort"),
      4,
      "post 1 starts with the expected retort buttons before interaction"
    );
    pretender.put("/retorts/398.json", () => {
      putEndpoint();
      return response(200);
    });
    pretender.delete("/retorts/398.json", () => {
      deleteEndpoint();
      return response(200);
    });
    await click(
      "#post_1 .post-retort-container button.post-retort:not(.disabled)"
    );
    assert.true(
      deleteEndpoint.calledOnce,
      "clicking an active current-user retort sends exactly one withdraw request"
    );
    assert.true(
      putEndpoint.notCalled,
      "clicking an active current-user retort does not send a create request"
    );
  });

  test("opens the picker and renders a new retort after emoji selection", async function (assert) {
    await visit("/t/retort-topic/114514");
    assert.false(
      visible(".emoji-picker"),
      "the emoji picker starts hidden before the trigger is clicked"
    );
    await click("#post_1 .actions button.retort");
    assert.true(
      visible(".emoji-picker"),
      "clicking the retort trigger opens the emoji picker"
    );
    await click(".emoji-picker__section-emojis img[title=':grinning:']");
    assert.false(
      visible(".emoji-picker"),
      "selecting an emoji closes the emoji picker again"
    );
    assert.true(
      visible("#post_1 button.post-retort:has(img[alt=':grinning:'])"),
      "the newly created grinning retort becomes visible on the post"
    );
  });

  test("shows and dismisses the error dialog after a failed retort request", async function (assert) {
    await visit("/t/retort-topic/114514");
    await click("#post_3 .not-my-retort");
    assert.true(
      visible("#dialog-holder"),
      "a failed retort request opens the error dialog"
    );
    await click("#dialog-holder .dialog-footer .btn-primary");
    assert.false(
      visible("#dialog-holder"),
      "confirming the dialog closes the error dialog again"
    );
  });

  test("updates rendered retorts when a message bus payload arrives", async function (assert) {
    await visit("/t/retort-topic/114514");
    await publishToMessageBus(
      "/retort/topics/114514",
      retortFixtures["/retort/topics/114514.json"]
    );
    assert.true(
      visible(
        "#post_1 .post-retort-container button.post-retort:has(img[alt=':innocent:'])"
      ),
      "the message bus payload adds the newly broadcast innocent retort"
    );
    assert.strictEqual(
      query(
        "#post_1 .post-retort-container button.post-retort:has(img[alt=':+1:']) .post-retort__count"
      ).innerText,
      "7",
      "the message bus payload updates the +1 retort count"
    );
    assert.strictEqual(
      query(
        "#post_1 .post-retort-container button.post-retort:has(img[alt=':smile:']) .post-retort__count"
      ).innerText,
      "2",
      "the message bus payload updates the smile retort count"
    );
    assert.true(
      visible(
        "#post_1 .post-retort-container button.post-retort.not-my-retort img[alt=':ocean:']"
      ),
      "the message bus payload keeps non-current-user retorts marked as not-my-retort"
    );
    assert.true(
      visible(
        "#post_1 .post-retort-container button.post-retort.my-retort img[alt=':+1:']"
      ),
      "the message bus payload keeps current-user retorts marked as my-retort"
    );
  });
});
