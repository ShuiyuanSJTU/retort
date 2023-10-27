import { h } from "virtual-dom";
import { createWidget } from "discourse/widgets/widget";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Retort from "../lib/retort";
import hbs from "discourse/widgets/hbs-compiler";

createWidget("retort-remove-emoji", {
  tagName: "a.remove-retort",
  template: hbs`{{d-icon "times"}}`,

  buildKey: (attrs) => `retort-remove-${attrs.post.id}-${attrs.emoji}`,

  defaultState({ emoji, post }) {
    return { emoji, post };
  },

  click() {
    const { post, emoji } = this.state;
    bootbox.confirm(
      I18n.t("retort.confirm_remove", { emoji }),
      (confirmed) => {
        if (confirmed) {
          Retort.removeRetort(post, emoji).catch(popupAjaxError);
        }
      }
    );
  },
});

export default createWidget("retort-toggle", {
  tagName: "button.post-retort",

  buildKey: (attrs) => `retort-toggle-${attrs.post.id}-${attrs.emoji}-${attrs.usernames.length}`,

  defaultState({ emoji, post, usernames, emojiUrl }) {
    const is_my_retort = (this.currentUser == null) ? false : usernames.includes(this.currentUser.username);
    return { emoji, post, usernames, emojiUrl, is_my_retort};
  },

  buildClasses() {
    if (this.state.usernames.length <= 0) return ["nobody-retort"];
    else if (this.state.is_my_retort) return ["my-retort"];
    else return ["not-my-retort"];
  },

  click() {
    const { post, emoji } = this.state;
    Retort.updateRetort(post, emoji).then(this.updateWidget.bind(this)).catch(popupAjaxError);
  },

  updateWidget() {
    if (this.currentUser == null) {
      return
    }
    if (this.state.is_my_retort) {
      const index = this.state.usernames.indexOf(this.currentUser.username);
      this.state.usernames.splice(index, 1);
      this.state.is_my_retort = false;
    } else {
      this.state.usernames.push(this.currentUser.username);
      this.state.is_my_retort = true;
    }
    this.scheduleRerender()
  },

  html(attrs) {
    const { emoji, usernames, emojiUrl } = this.state;
    const res = [
      h("img.emoji", { src: emojiUrl, alt: `:${emoji}:` }),
      h("span.post-retort__count", usernames.length.toString()),
      h("span.post-retort__tooltip", this.sentence(this.state)),
    ];
    if ((!Retort.disableRetortButton(this.state.post.id))
      && attrs.currentUser
      && (attrs.currentUser.trust_level == 4 || attrs.currentUser.staff)) {
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
