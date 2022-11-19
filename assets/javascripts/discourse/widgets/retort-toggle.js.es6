import { h } from "virtual-dom";
import { createWidget } from "discourse/widgets/widget";
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
          Retort.removeRetort(post, emoji);
        }
      }
    );
  },
});

export default createWidget("retort-toggle", {
  tagName: "button.post-retort",

  buildKey: (attrs) => `retort-toggle-${attrs.post.id}-${attrs.emoji}-${attrs.usernames.length}`,

  defaultState({ emoji, post, usernames, emojiUrl }) {
    return { emoji, post, usernames, emojiUrl };
  },

  buildClasses(attrs) {
    const { usernames, currentUser } = attrs;
    if (usernames.includes(currentUser.username)) return ["my-retort"];
    else return ["not-my-retort"];
  },

  click() {
    const { post, emoji } = this.state;
    Retort.updateRetort(post, emoji);
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
