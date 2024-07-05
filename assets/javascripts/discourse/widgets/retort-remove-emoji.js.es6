import { popupAjaxError } from "discourse/lib/ajax-error";
import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import I18n from "discourse-i18n";
import Retort from "../lib/retort";

createWidget("retort-remove-emoji", {
  tagName: "a.remove-retort",
  template: hbs`{{d-icon "times"}}`,

  buildKey: (attrs) => `retort-remove-${attrs.post.id}-${attrs.emoji}`,

  defaultState({ emoji, post }) {
    return { emoji, post };
  },

  click() {
    const { post, emoji } = this.state;
    const dialog = getOwnerWithFallback(this).lookup("service:dialog");
    dialog.confirm({
      title: I18n.t("retort.confirm_remove.title"),
      message: I18n.t("retort.confirm_remove.message", { emoji }),
      didConfirm: () => Retort.removeRetort(post, emoji).catch(popupAjaxError),
    });
  },
});
