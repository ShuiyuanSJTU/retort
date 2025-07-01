import Component from "@glimmer/component";
import { service } from "@ember/service";
import { emojiUrlFor } from "discourse/lib/text";
import RetortToggleButton from "./retort-toggle-button";

export default class PostRetortContainer extends Component {
  @service retort;
  @service currentUser;

  get shouldRender() {
    if (!this.args.post) {
      return false;
    }
    return !this.retort.disableShowForTopic(this.args.post.topic);
  }

  get retorts() {
    if (!this.args.post.retorts) {
      return [];
    }

    const retorts = this.args.post.retorts
      .map((item) => {
        return { ...item, emojiUrl: emojiUrlFor(item.emoji) };
      })
      .filter(({ emojiUrl }) => emojiUrl)
      .sort((a, b) => a.emoji.localeCompare(b.emoji));

    return retorts
      .map(({ emoji, emojiUrl, usernames }) => {
        let displayUsernames = usernames;
        if (this.currentUser?.custom_fields?.hide_ignored_retorts) {
          const ignoredUsers = new Set(this.currentUser.ignored_users || []);
          displayUsernames = usernames.filter((username) => {
            return !ignoredUsers.has(username);
          });
        }
        if (displayUsernames.length > 0) {
          return {
            emoji,
            emojiUrl,
            post: this.args.post,
            usernames: displayUsernames,
          };
        }
        return null;
      })
      .filter(Boolean);
  }

  <template>
    {{#if this.shouldRender}}
      <div class="post-retort-container">
        {{#each this.retorts as |retort|}}
          <RetortToggleButton
            @emoji={{retort.emoji}}
            @emojiUrl={{retort.emojiUrl}}
            @usernames={{retort.usernames}}
            @post={{retort.post}}
          />
        {{/each}}
      </div>
    {{/if}}
  </template>
}
