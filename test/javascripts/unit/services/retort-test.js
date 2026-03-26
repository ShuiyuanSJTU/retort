import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Retort | Unit | Service | retort", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.subject = this.owner.lookup("service:retort");
    this.subject.siteSettings = this.owner.lookup("service:site-settings");
  });

  test("parses disabled category ids and ignores non-numeric entries", function (assert) {
    this.subject.siteSettings.retort_disabled_categories = "2|foo|5|0||7";

    assert.deepEqual(
      this.subject.disabledCategories(),
      [2, 5, 7],
      "the service returns only valid positive category ids from the site setting"
    );
  });

  test("hides retorts for missing topics and topics in disabled categories", function (assert) {
    this.subject.siteSettings.retort_disabled_categories = "2|5";

    assert.true(
      this.subject.disableShowForTopic(),
      "the service hides retorts when there is no topic to inspect"
    );
    assert.true(
      this.subject.disableShowForTopic(
        EmberObject.create({
          category: EmberObject.create({ id: 2 }),
        })
      ),
      "the service hides retorts when the topic belongs to a disabled category"
    );
    assert.false(
      this.subject.disableShowForTopic(
        EmberObject.create({
          category: EmberObject.create({ id: 9 }),
        })
      ),
      "the service keeps retorts visible when the topic category is allowed"
    );
  });
});
