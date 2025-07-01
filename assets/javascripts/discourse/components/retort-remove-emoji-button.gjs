import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class RetortRemoveEmojiButton extends Component {
  @service dialog;
  @service retort;

  @action
  click() {
    const { post, emoji } = this.args;
    this.dialog.confirm({
      title: i18n("retort.confirm_remove.title"),
      message: i18n("retort.confirm_remove.message", { emoji }),
      didConfirm: () =>
        this.retort.removeRetort(post, emoji).catch(popupAjaxError),
    });
  }

  <template>
    <div class="remove-retort" role="button" {{on "click" this.click}}>
      {{icon "xmark"}}
    </div>
  </template>
}
