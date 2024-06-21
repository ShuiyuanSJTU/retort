import { withPluginApi } from "discourse/lib/plugin-api";
import Retort from "../lib/retort";

function initializePlugin(api) {
  const { retort_enabled } = api.container.lookup("site-settings:main");

  if (!retort_enabled) {
    return;
  }
  const currentUser = api.getCurrentUser();

  api.modifyClass("controller:preferences/notifications", {
    pluginId: "retort",
    actions: {
      save() {
        this.get('saveAttrNames').push('custom_fields');
        this._super();
      }
    }
  });

  if (currentUser?.custom_fields?.disable_retorts) {return;}

  api.decorateWidget("post-contents:after-cooked", (helper) => {
    let postId = helper.getModel().id;
    let post = Retort.postFor(postId);

    return helper.attach("post-retort-container", { post, currentUser });
  });


  api.addPostClassesCallback((attrs) => {
    if (!Retort.disableShowForPost(attrs.id)) {
      return ["retort"];
    }
  });

  api.modifyClass("route:topic", {
    pluginId: "retort",

    setupController(controller, model) {
      Retort.activate(model);
      this._super(controller, model);
    },

    deactivate() {
      Retort.deactivate();
      this._super();
    }
  });

  api.addPostMenuButton("retort", (attrs) => {
    const post = Retort.postFor(attrs.id);
    if (!post.can_retort) {
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
    const post = this.findAncestorModel();
    Retort.openPicker(post);
  });

}

export default {
  name: "retort-button",
  initialize: function () {
    withPluginApi("0.8.6", (api) => initializePlugin(api));
  },
};
