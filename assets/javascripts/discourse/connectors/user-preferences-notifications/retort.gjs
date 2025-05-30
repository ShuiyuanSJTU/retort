import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import { i18n } from "discourse-i18n";

@tagName("div")
@classNames("user-preferences-notifications-outlet", "retort")
export default class Retort extends Component {
  <template>
    {{#if this.siteSettings.retort_enabled}}
      <div class="control-group retort">
        <label class="control-label">{{i18n "retort.retort"}}</label>
        <div class="controls">
          <PreferenceCheckbox
            @labelKey="retort.disable_retorts"
            @checked={{this.model.custom_fields.disable_retorts}}
          />
        </div>
        <div class="controls">
          <PreferenceCheckbox
            @labelKey="retort.hide_ignored_retorts"
            @checked={{this.model.custom_fields.hide_ignored_retorts}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}
