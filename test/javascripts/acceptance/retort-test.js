import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  count,
  exists,
  query,
  queryAll,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import retortFixtures from "../fixtures/topic-with-retort";

acceptance("Poll results", function (needs) {
  needs.user({ username: "pangbo" });
  needs.settings({ retort_withdraw_tolerance: 3600 });

  needs.pretender((server, helper) => {
    // server.get("/posts/by_number/134/1", () => {
    //   return helper.response({
    //     id: 156,
    //     name: null,
    //     username: "bianca",
    //     avatar_template: "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
    //     created_at: "2021-06-08T21:56:55.166Z",
    //     cooked:
    //       '\u003cdiv class="poll" data-poll-status="open" data-poll-public="true" data-poll-results="always" data-poll-charttype="bar" data-poll-type="regular" data-poll-name="poll"\u003e\n\u003cdiv\u003e\n\u003cdiv class="poll-container"\u003e\n\u003cul\u003e\n\u003cli data-poll-option-id="db753fe0bc4e72869ac1ad8765341764"\u003eOption \u003cspan class="hashtag"\u003e#1\u003c/span\u003e\n\u003c/li\u003e\n\u003cli data-poll-option-id="d8c22ff912e03740d9bc19e133e581e0"\u003eOption \u003cspan class="hashtag"\u003e#2\u003c/span\u003e\n\u003c/li\u003e\n\u003c/ul\u003e\n\u003c/div\u003e\n\u003cdiv class="poll-info"\u003e\n\u003cp\u003e\n\u003cspan class="info-number"\u003e0\u003c/span\u003e\n\u003cspan class="info-label"\u003evoters\u003c/span\u003e\n\u003c/p\u003e\n\u003c/div\u003e\n\u003c/div\u003e\n\u003c/div\u003e',
    //     post_number: 1,
    //     post_type: 1,
    //     updated_at: "2021-06-08T21:59:16.444Z",
    //     reply_count: 0,
    //     reply_to_post_number: null,
    //     quote_count: 0,
    //     incoming_link_count: 0,
    //     reads: 2,
    //     readers_count: 1,
    //     score: 0,
    //     yours: true,
    //     topic_id: 134,
    //     topic_slug: "retort-topic",
    //     display_username: null,
    //     primary_group_name: null,
    //     flair_url: null,
    //     flair_bg_color: null,
    //     flair_color: null,
    //     version: 1,
    //     can_edit: true,
    //     can_delete: false,
    //     can_recover: false,
    //     can_wiki: true,
    //     title_is_group: false,
    //     bookmarked: false,
    //     bookmarks: [],
    //     raw: "[poll type=regular results=always public=true chartType=bar]\n* Option #1\n* Option #2\n[/poll]",
    //     actions_summary: [
    //       { id: 3, can_act: true },
    //       { id: 4, can_act: true },
    //       { id: 8, can_act: true },
    //       { id: 7, can_act: true },
    //     ],
    //     moderator: false,
    //     admin: true,
    //     staff: true,
    //     user_id: 1,
    //     hidden: false,
    //     trust_level: 0,
    //     deleted_at: null,
    //     user_deleted: false,
    //     edit_reason: null,
    //     can_view_edit_history: true,
    //     wiki: false,
    //     reviewable_id: null,
    //     reviewable_score_count: 0,
    //     reviewable_score_pending_count: 0,
    //     calendar_details: [],
    //     can_accept_answer: false,
    //     can_unaccept_answer: false,
    //     accepted_answer: false,
    //     polls: [
    //       {
    //         name: "poll",
    //         type: "regular",
    //         status: "open",
    //         public: true,
    //         results: "always",
    //         options: [
    //           {
    //             id: "db753fe0bc4e72869ac1ad8765341764",
    //             html: 'Option \u003cspan class="hashtag"\u003e#1\u003c/span\u003e',
    //             votes: 1,
    //           },
    //           {
    //             id: "d8c22ff912e03740d9bc19e133e581e0",
    //             html: 'Option \u003cspan class="hashtag"\u003e#2\u003c/span\u003e',
    //             votes: 0,
    //           },
    //         ],
    //         voters: 1,
    //         preloaded_voters: {
    //           db753fe0bc4e72869ac1ad8765341764: [
    //             {
    //               id: 1,
    //               username: "bianca",
    //               name: null,
    //               avatar_template:
    //                 "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
    //             },
    //           ],
    //         },
    //         chart_type: "bar",
    //         title: null,
    //       },
    //     ],
    //     polls_votes: { poll: ["db753fe0bc4e72869ac1ad8765341764"] },
    //   });
    // });

    server.get("/t/114514.json", () => {
      return helper.response(
        retortFixtures["/t/114514.json"]
      );
    });

    server.post("/retorts/398.json", () => {
      return helper.success();
    });

    server.post("/retorts/421.json", () => helper.response(403, {
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
      query("#post_1 .post-retort-container button.post-retort.my-retort[disabled=true] img").getAttribute('alt'),
      ":pouting_cat:",
      "The retort button is disabled"
    );
    assert.strictEqual(
      query("#post_1 .post-retort-container button.post-retort.my-retort:not([disabled=true]) img").getAttribute('alt'),
      ":+1:",
      "The retort button is enabled"
    );
  });

  test("disabled retort ", async function (assert) {
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
    // await pauseTest();
    assert.strictEqual(
      count("#post_2 .post-retort-container button.post-retort[disabled=true] img"),
      3,
      "The retort button is disabled"
    );
    assert.ok(
      !exists("#post_2 .post-retort-container button.post-retort:not([disabled=true]) img"),
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

  test("create or withdraw", async function (assert) {
    await visit("/t/retort-topic/114514");
    assert.strictEqual(
      count("#post_1 .post-retort-container button.post-retort"),
      4,
      "There are 4 retorts in the post"
    );
    for (const el of queryAll("#post_1 .post-retort-container button.post-retort:not([disabled=true])")) {
      await click(el);
    }
    assert.ok(
      !query("#post_1 button.post-retort:has(img[alt=':+1:'])").classList.contains("my-retort")
    );
    assert.strictEqual(
      query("#post_1 button.post-retort:has(img[alt=':+1:']) .post-retort__count").innerText,
      "6",
    );
    assert.ok(
      query("#post_1 button.post-retort:has(img[alt=':ocean:'])").classList.contains("my-retort")
    );
    assert.strictEqual(
      query("#post_1 button.post-retort:has(img[alt=':ocean:']) .post-retort__count").innerText,
      "9",
    );
    assert.ok(
      !visible("#post_1 button.post-retort:has(img[alt=':smile:'])")
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
    await click("#post_1");
    assert.ok(
      !visible(".emoji-picker"),
      "The emoji picker is not visible"
    );
  });

  test("pop ajax error", async function (assert) {
    await visit("/t/retort-topic/114514");
    await click("#post_3 .not-my-retort");
    assert.ok(
      visible("#dialog-holder"),
      "The dialog is visible"
    );
    assert.strictEqual(
      query("#dialog-holder .dialog-body").innerText,
      "An error occurred: FAIL",
    );
    await click("#dialog-holder .dialog-footer .btn-primary");
    assert.ok(
      !visible("#dialog-holder"),
      "The dialog is not visible"
    );
  });
});
