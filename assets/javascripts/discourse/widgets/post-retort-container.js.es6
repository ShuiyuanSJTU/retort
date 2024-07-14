import { emojiUrlFor } from "discourse/lib/text";
import { createWidget } from "discourse/widgets/widget";
import Retort from "../lib/retort";

createWidget("post-retort-container", {
  tagName: "div.post-retort-container",

  buildKey: (attrs) => `post-retort-container-${attrs.post.id}`,

  html(attrs) {
    const { post } = attrs;
    if (Retort.disableShowForTopic(post.topic)) {
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
      if (this.currentUser?.custom_fields?.hide_ignored_retorts) {
        const ignoredUsers = new Set(this.currentUser.ignored_users);
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
        });
      } else {
        return null;
      }
    });
    return retort_widgets;
  },
});
