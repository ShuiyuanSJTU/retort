import { h } from "virtual-dom";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { createWidget } from "discourse/widgets/widget";
import I18n from "discourse-i18n";
import Retort from "../lib/retort";

export default createWidget("retort-toggle", {
  tagName: "button.post-retort",

  buildKey: (attrs) => `retort-toggle-${attrs.post.id}-${attrs.emoji}-${attrs.usernames.length}`,

  defaultState({ emoji, post, usernames, emojiUrl }) {
    const my_retort = post.my_retorts?.find((retort) => retort.emoji === emoji);
    const isMyRetort = my_retort ? true : false;
    const myRetortUpdateTime = isMyRetort ? new Date(my_retort?.updated_at) : undefined;
    const displayUsernames = Array.from(usernames);
    return { emoji, post, displayUsernames, emojiUrl, isMyRetort, myRetortUpdateTime};
  },

  buildClasses() {
    const classList = [];
    if (this.state.displayUsernames.length <= 0) { classList.push("nobody-retort");}
    else if (this.state.isMyRetort) { classList.push("my-retort");}
    else { classList.push("not-my-retort"); }
    if (this.disabled()) { classList.push("disabled"); }
    return classList;
  },

  click() {
    if (this.currentUser == null || this.disabled()) {
      return;
    }
    const { post, emoji } = this.state;
    Retort.updateRetort(post, emoji)
      .then(() => Retort.localUpdateWidget(post.id, emoji))
      .catch(popupAjaxError);
  },

  disabled() {
    if (!this.state.post.can_retort) { return true; }
    if (this.state.isMyRetort) {
      const diff = new Date() - this.state.myRetortUpdateTime;
      if (diff > this.siteSettings.retort_withdraw_tolerance * 1000) {
        // cannot withdraw if exceeding torlerance time
        return true;
      }
    }
    return false;
  },

  html(attrs) {
    const { emoji, displayUsernames, emojiUrl } = this.state;
    if (displayUsernames.length <= 0) {return [];}
    const res = [
      h("img.emoji", { src: emojiUrl, alt: `:${emoji}:` }),
      h("span.post-retort__count", displayUsernames.length.toString()),
      h("span.post-retort__tooltip", this.sentence(this.state)),
    ];
    if (attrs.post.can_remove_retort) {
      res.push(this.attach("retort-remove-emoji", attrs));
    }
    return res;
  },

  sentence({ displayUsernames, emoji }) {
    let key;
    switch (displayUsernames.length) {
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
      first: displayUsernames[0],
      second: displayUsernames[1],
      count: displayUsernames.length - 2,
    });
  },
});
