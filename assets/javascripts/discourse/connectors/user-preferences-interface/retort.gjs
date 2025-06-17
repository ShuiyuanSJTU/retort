import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import { i18n } from "discourse-i18n";

@tagName("fieldset")
@classNames("retort")
export default class Retort extends Component {
  <template>
    {{#if this.siteSettings.retort_enabled}}
      <fieldset class="control-group retort">
        <legend class="control-label">{{i18n "retort.preference_title"}}</legend>
        <div class="controls">
          <PreferenceCheckbox
            @labelKey="retort.disable_retorts"
            @checked={{@model.custom_fields.disable_retorts}}
          />
        </div>
        <div class="controls">
          <PreferenceCheckbox
            @labelKey="retort.hide_ignored_retorts"
            @checked={{@model.custom_fields.hide_ignored_retorts}}
          />
        </div>
      </fieldset>
    {{/if}}
  </template>
}
