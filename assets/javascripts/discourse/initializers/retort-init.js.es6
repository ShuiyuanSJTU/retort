import { withPluginApi } from "discourse/lib/plugin-api";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import RetortButton from "../components/retort-button";
import { action } from "@ember/object";

function initializePlugin(api) {
  const currentUser = api.getCurrentUser();

  api.modifyClass("controller:preferences/notifications", (Superclass) => 
    class extends Superclass {
      @action
      save() {
        this.get("saveAttrNames").push("custom_fields");
        super.save();
      }
    }
  );

  if (currentUser?.custom_fields?.disable_retorts) {
    return;
  }

  api.includePostAttributes("can_retort", "my_retorts", "retorts");

  api.decorateWidget("post-contents:after-cooked", (helper) => {
    const post = helper.getModel();
    return helper.attach("post-retort-container", { post });
  });

  api.addPostClassesCallback((attrs) => {
    const Retort = getOwnerWithFallback(api).lookup("service:retort");
    if (!Retort.disableShowForTopic(attrs.topic)) {
      return ["retort"];
    }
  });

  api.modifyClass("controller:topic", (Superclass) =>
    class extends Superclass {
      onRetortUpdate(data) {
        const { id, retorts } = data;
        const post = this.get("model.postStream.posts").findBy("id", id);
        if (post) {
          post.setProperties({ retorts });
          this.appEvents.trigger("post-stream:refresh", { id: post.get("id") });
        }
      }

      subscribe() {
        super.subscribe();
        this.messageBus.subscribe(
          `/retort/topics/${this.get("model.id")}`,
          this.onRetortUpdate.bind(this)
        );
      }

      unsubscribe() {
        super.unsubscribe();
        this.messageBus.unsubscribe("/retort/topics/*");
      }
    }
  );

  api.registerValueTransformer(
    "post-menu-buttons",
    ({
      value: dag, 
      context: {
        firstButtonKey,
      },
    }) => {
        dag.add(
          "retort",
          RetortButton,
          {
            before: firstButtonKey,
          }
        );
    }
  );
}

export default {
  name: "retort",
  initialize: function (container) {
    if (!container.lookup("service:site-settings").retort_enabled) {
      return;
    }
    withPluginApi("1.3", (api) => initializePlugin(api));
  },
};
