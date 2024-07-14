import { h } from "virtual-dom";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { createWidget } from "discourse/widgets/widget";
import I18n from "discourse-i18n";
import Retort from "../lib/retort";

export default createWidget("retort-toggle", {
  tagName: "button.post-retort",

  buildClasses(attrs) {
    const classList = [];
    if (attrs.usernames.length <= 0) {
      classList.push("nobody-retort");
    } else if (this.isMyRetort()) {
      classList.push("my-retort");
    } else {
      classList.push("not-my-retort");
    }
    if (this.disabled()) {
      classList.push("disabled");
    }
    return classList;
  },

  click() {
    if (this.currentUser == null || this.disabled()) {
      return;
    }
    const { post, emoji } = this.attrs;
    if (this.isMyRetort()) {
      Retort.withdrawRetort(post, emoji)
        .then((data) => {
          post.set("retorts", data.retorts);
          this.scheduleRerender();
        })
        .catch(popupAjaxError);
    } else {
      Retort.createRetort(post, emoji)
        .then((data) => {
          post.set("retorts", data.retorts);
          this.scheduleRerender();
        })
        .catch(popupAjaxError);
    }
  },

  isMyRetort() {
    return this.attrs.usernames.any((username) => username === this.currentUser?.username);
  },

  myRetortUpdateTime() {
    const my_retort = this.attrs.post.my_retorts?.find(
      (retort) => retort.emoji === this.attrs.emoji
    );
    return my_retort ? new Date(my_retort?.updated_at) : undefined;
  },

  disabled() {
    if (!this.attrs.post.can_retort) {
      return true;
    }
    if (this.isMyRetort()) {
      const diff = new Date() - this.myRetortUpdateTime();
      if (diff > this.siteSettings.retort_withdraw_tolerance * 1000) {
        // cannot withdraw if exceeding torlerance time
        return true;
      }
    }
    return false;
  },

  html(attrs) {
    const { emoji, usernames, emojiUrl } = this.attrs;
    if (usernames.length <= 0) {
      return [];
    }
    const res = [
      h("img.emoji", { src: emojiUrl, alt: `:${emoji}:` }),
      h("span.post-retort__count", usernames.length.toString()),
      h("span.post-retort__tooltip", this.sentence(this.attrs)),
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
