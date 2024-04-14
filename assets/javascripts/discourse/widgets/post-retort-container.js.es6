import { popupAjaxError } from "discourse/lib/ajax-error";
import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import I18n from "discourse-i18n";
import Retort from "../lib/retort";
import { emojiUrlFor } from "discourse/lib/text";

createWidget("post-retort-container", {
  tagName: "div.post-retort-container",

  buildKey: (attrs) => `post-retort-container-${attrs.post.id}`,

  defaultState({ post }) {
    return { post };
  },

  init(attrs) {
    Retort.storeWidget(attrs.post.id, this);
  },

  destroy() {
    Retort.removeStoredWidget(this.state.post.id);
  },

  html(attrs) {
    const { post, currentUser } = attrs;
    if (Retort.disableShowForPost(post.id)) {
      return;
    }

    if (!post.retorts) {
      return;
    }

    const retorts = post.retorts
      .map((item) => {
        item.emojiUrl = emojiUrlFor(item.emoji);
        return item;
      })
      .filter(({ emojiUrl }) => emojiUrl)
      .sort((a, b) => a.emoji.localeCompare(b.emoji));
    const retort_widgets = retorts.map(({ emoji, emojiUrl, usernames }) => {
        let displayUsernames = usernames;
        // check if hide_ignored_retorts is enabled
        if (currentUser?.custom_fields?.hide_ignored_retorts) {
          const ignoredUsers = new Set(currentUser.ignored_users);
          displayUsernames = usernames.filter((username) => {
            return !ignoredUsers.has(username);
          });
        }
        if (displayUsernames.length > 0) {
          return this.attach("retort-toggle", {
            emoji,
            emojiUrl,
            post,
            usernames: displayUsernames,
            currentUser,
          });
        }
        else {
          return null;
        }
      }
    );
    return retort_widgets;
  }
});