import { withPluginApi } from "discourse/lib/plugin-api";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";

function initializePlugin(api) {
  const currentUser = api.getCurrentUser();

  api.modifyClass("controller:preferences/notifications", {
    pluginId: "retort",
    actions: {
      save() {
        this.get("saveAttrNames").push("custom_fields");
        this._super();
      },
    },
  });

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

  api.modifyClass("controller:topic", {
    pluginId: "retort",

    onRetortUpdate(data) {
      const { id, retorts } = data;
      const post = this.get("model.postStream.posts").findBy("id", id);
      if (post) {
        post.setProperties({ retorts });
        this.appEvents.trigger("post-stream:refresh", { id: post.get("id") });
      }
    },

    subscribe() {
      this._super();

      this.messageBus.subscribe(
        `/retort/topics/${this.get("model.id")}`,
        this.onRetortUpdate.bind(this)
      );
    },

    unsubscribe() {
      this._super();
      this.messageBus.unsubscribe("/retort/topics/*");
    }
  });

  api.addPostMenuButton("retort", ({ can_retort }) => {
    if (!can_retort) {
      return;
    }
    return {
      action: "clickRetort",
      icon: "far-smile",
      title: "retort.title",
      position: "first",
      className: "retort",
    };
  });

  api.attachWidgetAction("post-menu", "clickRetort", function () {
    const Retort = getOwnerWithFallback(api).lookup("service:retort");
    const post = this.findAncestorModel();
    Retort.openPicker(post);
  });
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
