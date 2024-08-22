import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import pretender, {response} from "discourse/tests/helpers/create-pretender";
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
      return helper.response(
        retortFixtures["/t/114514.json"]
      );
    });

    server.put("/retorts/398.json", () => {
      return helper.response(
        retortFixtures["put:/retorts/398.json"]
      );
    });

    server.put("/retorts/421.json", () => helper.response(403, {
      "errors": [
        "FAIL"
      ],
    }));
  });

  test("show retort", async function (assert) {
    await visit("/t/retort-topic/114514");

    assert.strictEqual(
      count("#post_1 .post-retort-container button.post-retort"),
      4,
      "There are 4 retorts in the post"
    );
    assert.strictEqual(
      count("#post_1 .post-retort-container button.post-retort.my-retort"),
      3,
      "There are 3 retorts from the current user"
    );
    assert.ok(
      visible("#post_1 .actions button.retort"),
      "The retort button is visible"
    );
    assert.strictEqual(
      query("#post_1 .post-retort-container button.post-retort.my-retort.disabled img").getAttribute('alt'),
      ":pouting_cat:",
      "The retort button is disabled"
    );
    assert.strictEqual(
      query("#post_1 .post-retort-container button.post-retort.my-retort:not(.disabled) img").getAttribute('alt'),
      ":+1:",
      "The retort button is enabled"
    );
  });

  test("disabled retort", async function (assert) {
    await visit("/t/retort-topic/114514");

    assert.strictEqual(
      count("#post_2 .post-retort-container button.post-retort"),
      3,
      "There are 3 retorts in the post"
    );
    assert.strictEqual(
      count("#post_2 .post-retort-container button.post-retort.my-retort"),
      2,
      "There are 2 retorts from the current user"
    );
    assert.ok(
      !visible("#post_2 .actions button.retort"),
      "The retort button is not visible"
    );
    assert.strictEqual(
      count("#post_2 .post-retort-container button.post-retort.disabled img"),
      3,
      "The retort button is disabled"
    );
    assert.ok(
      !exists("#post_2 .post-retort-container button.post-retort:not(.disabled) img"),
      "No retort button is enabled"
    );
  });

  test("can remove retort", async function (assert) {
    await visit("/t/retort-topic/114514");

    assert.strictEqual(
      count("#post_3 .post-retort-container button.post-retort .remove-retort"),
      3,
      "There are 3 remove retorts btn in the post"
    );
  });

  test("make requests", async function (assert) {
    const putEndpoint = sinon.spy();
    const deleteEndpoint = sinon.spy();
    await visit("/t/retort-topic/114514");
    assert.strictEqual(
      count("#post_1 .post-retort-container button.post-retort"),
      4,
      "There are 4 retorts in the post"
    );
    pretender.put("/retorts/398.json", () => {
      putEndpoint();
      return response(200);
    });
    pretender.delete("/retorts/398.json", () => {
      deleteEndpoint();
      return response(200);
    });
    await click("#post_1 .post-retort-container button.post-retort:not(.disabled)");
    assert.strictEqual(
      deleteEndpoint.calledOnce,
      true,
      "requested once for withdraw"
    );
    assert.strictEqual(
      putEndpoint.notCalled,
      true,
      "no request for create"
    );
  });

  test("pop selector", async function (assert) {
    await visit("/t/retort-topic/114514");
    assert.ok(
      !visible(".emoji-picker"),
      "The emoji picker is not visible"
    );
    await click("#post_1 .actions button.retort");
    assert.ok(
      visible(".emoji-picker"),
      "The emoji picker is visible"
    );
    await click(".emoji-picker .section-group img[title='melting_face']");
    assert.ok(
      !visible(".emoji-picker"),
      "The emoji picker is not visible"
    );
    assert.ok(
      visible("#post_1 button.post-retort:has(img[alt=':melting_face:'])"),
      "New retort is visible"
    );
  });

  test("pop ajax error", async function (assert) {
    await visit("/t/retort-topic/114514");
    await click("#post_3 .not-my-retort");
    assert.ok(
      visible("#dialog-holder"),
      "The dialog is visible"
    );
    await click("#dialog-holder .dialog-footer .btn-primary");
    assert.ok(
      !visible("#dialog-holder"),
      "The dialog is not visible"
    );
  });

  test("message bus", async function (assert) {
    await visit("/t/retort-topic/114514");
    await publishToMessageBus("/retort/topics/114514",
      retortFixtures["/retort/topics/114514.json"]);
    assert.ok(
      visible("#post_1 .post-retort-container button.post-retort:has(img[alt=':innocent:'])"),
    );
    assert.strictEqual(
      query("#post_1 .post-retort-container button.post-retort:has(img[alt=':+1:']) .post-retort__count").innerText,
      "7",
    );
    assert.strictEqual(
      query("#post_1 .post-retort-container button.post-retort:has(img[alt=':smile:']) .post-retort__count").innerText,
      "2",
    );
    assert.ok(
      visible("#post_1 .post-retort-container button.post-retort.not-my-retort img[alt=':ocean:']"),
    );
    assert.ok(
      visible("#post_1 .post-retort-container button.post-retort.my-retort img[alt=':+1:']"),
    );
  });
});
