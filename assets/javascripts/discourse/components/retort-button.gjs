import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import EmojiPicker from "discourse/components/emoji-picker";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class RetortButton extends Component {
  static hidden(args) {
    return !args.post.can_retort;
  }

  @service retort;
  @service appEvents;

  @action
  onSelectEmoji(emoji) {
    this.retort
      .createRetort(this.args.post, emoji)
      .then((data) => {
        this.args.post.set("retorts", data.retorts);
        this.args.post.set("my_retorts", data.my_retorts);
        this.appEvents.trigger("post-stream:refresh", { id: data.id });
      })
      .catch(popupAjaxError);
  }

  <template>
    <EmojiPicker
      ...attributes
      @icon="far-face-smile"
      @didSelectEmoji={{this.onSelectEmoji}}
      @btnClass="btn-icon btn-flat post-action-menu__retort retort"
    />
  </template>
}
