import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import RetortRemoveEmojiButton from "./retort-remove-emoji-button";

export default class RetortToggleButton extends Component {
  @service currentUser;
  @service retort;
  @service siteSettings;

  get classNames() {
    const classList = [];
    if (this.args.usernames.length <= 0) {
      classList.push("nobody-retort");
    } else if (this.isMyRetort) {
      classList.push("my-retort");
    } else {
      classList.push("not-my-retort");
    }
    if (this.disabled) {
      classList.push("disabled");
    }
    return classList;
  }

  @action
  click() {
    if (this.currentUser == null || this.disabled) {
      return;
    }
    const { post, emoji } = this.args;
    if (this.isMyRetort) {
      this.retort
        .withdrawRetort(post, emoji)
        .then((data) => {
          post.set("retorts", data.retorts);
          post.set("my_retorts", data.my_retorts);
        })
        .catch(popupAjaxError);
    } else {
      this.retort
        .createRetort(post, emoji)
        .then((data) => {
          post.set("retorts", data.retorts);
          post.set("my_retorts", data.my_retorts);
        })
        .catch(popupAjaxError);
    }
  }

  get isMyRetort() {
    return (
      this.args.usernames.findIndex(
        (username) => username === this.currentUser?.username
      ) > -1
    );
  }

  get myRetortUpdateTime() {
    const my_retort = this.args.post.my_retorts?.find(
      (retort) => retort.emoji === this.args.emoji
    );
    return my_retort ? new Date(my_retort?.updated_at) : undefined;
  }

  get disabled() {
    if (!this.args.post.can_retort) {
      return true;
    }
    if (this.isMyRetort) {
      const diff = new Date() - this.myRetortUpdateTime;
      if (diff > this.siteSettings.retort_withdraw_tolerance * 1000) {
        // cannot withdraw if exceeding torlerance time
        return true;
      }
    }
    return false;
  }

  get tooltipContent() {
    const { emoji, usernames } = this.args;
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

    return i18n(key, {
      emoji,
      first: usernames[0],
      second: usernames[1],
      count: usernames.length - 2,
    });
  }

  <template>
    <button
      class={{concatClass "post-retort" this.classNames}}
      type="button"
      {{on "click" this.click}}
    >
      <img class="emoji" src={{@emojiUrl}} alt={{concat ":" @emoji ":"}} />
      <span class="post-retort__count">{{@usernames.length}}</span>
      <span class="post-retort__tooltip">{{this.tooltipContent}}</span>
      {{#if @post.can_remove_retort}}
        <RetortRemoveEmojiButton @emoji={{@emoji}} @post={{@post}} />
      {{/if}}
    </button>
  </template>
}
