import { popupAjaxError } from "discourse/lib/ajax-error";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import { i18n } from "discourse-i18n";

createWidget("retort-remove-emoji", {
  tagName: "a.remove-retort",
  template: hbs`{{d-icon "xmark"}}`,
  services: ["retort"],

  buildKey: (attrs) => `retort-remove-${attrs.post.id}-${attrs.emoji}`,

  defaultState({ emoji, post }) {
    return { emoji, post };
  },

  click() {
    const { post, emoji } = this.state;
    const dialog = getOwnerWithFallback(this).lookup("service:dialog");
    dialog.confirm({
      title: i18n("retort.confirm_remove.title"),
      message: i18n("retort.confirm_remove.message", { emoji }),
      didConfirm: () =>
        this.retort.removeRetort(post, emoji).catch(popupAjaxError),
    });
  },
});
