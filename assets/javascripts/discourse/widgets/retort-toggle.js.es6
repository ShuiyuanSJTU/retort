import { h } from "virtual-dom";
import { popupAjaxError } from "discourse/lib/ajax-error";
import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import { getOwnerWithFallback  } from "discourse-common/lib/get-owner";
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
      }
    );
  },
});

export default createWidget("retort-toggle", {
  tagName: "button.post-retort",

  buildKey: (attrs) => `retort-toggle-${attrs.post.id}-${attrs.emoji}-${attrs.usernames.length}`,

  defaultState({ emoji, post, usernames, emojiUrl }) {
    const my_retort = post.my_retorts?.find((retort) => retort.emoji === emoji);
    const is_my_retort = my_retort ? true : false;
    const my_retort_update_time = is_my_retort ? new Date(my_retort?.updated_at) : undefined;
    return { emoji, post, usernames, emojiUrl, is_my_retort, my_retort_update_time};
  },

  buildClasses() {
    if (this.state.usernames.length <= 0) {return ["nobody-retort"];}
    else if (this.state.is_my_retort) {return ["my-retort"];}
    else {return ["not-my-retort"];}
  },

  // eslint-disable-next-line no-unused-vars
  buildAttributes(attrs) {
    if (this.disabled()) { return { disabled: true }; }
    return {};
  },

  click() {
    if (this.currentUser == null) {
      return;
    }
    const { post, emoji } = this.state;
    Retort.updateRetort(post, emoji).then(this.updateWidget.bind(this)).catch(popupAjaxError);
  },

  disabled() {
    if (!this.state.post.can_retort) {return true;}
    if (this.state.is_my_retort) {
      const diff = new Date() - this.state.my_retort_update_time;
      if (diff > this.siteSettings.retort_withdraw_tolerance * 1000) {
        // cannot withdraw if exceeding torlerance time
        return true;
      }
    }
    return false;
  },

  updateWidget() {
    if (this.currentUser == null) {
      return;
    }
    if (this.state.is_my_retort) {
      const index = this.state.usernames.indexOf(this.currentUser.username);
      this.state.usernames.splice(index, 1);
      this.state.is_my_retort = false;
    } else {
      this.state.usernames.push(this.currentUser.username);
      this.state.is_my_retort = true;
      this.state.my_retort_update_time = new Date();
    }
    this.scheduleRerender();
  },

  html(attrs) {
    const { emoji, usernames, emojiUrl } = this.state;
    if (usernames.length <= 0) {return [];}
    const res = [
      h("img.emoji", { src: emojiUrl, alt: `:${emoji}:` }),
      h("span.post-retort__count", usernames.length.toString()),
      h("span.post-retort__tooltip", this.sentence(this.state)),
    ];
    if (attrs.post.can_remove_retort) {
      res.push(this.attach("retort-remove-emoji", attrs));
    }
    return res;
  },

  sentence({ usernames, emoji }) {
    let key;
    switch (usernames.length) {
      case 1:
        key = "retort.reactions.one_person";
        break;
      case 2:
        key = "retort.reactions.two_people";
        break;
      default:
        key = "retort.reactions.many_people";
        break;
    }

    return I18n.t(key, {
      emoji,
      first: usernames[0],
      second: usernames[1],
      count: usernames.length - 2,
    });
  },
});
