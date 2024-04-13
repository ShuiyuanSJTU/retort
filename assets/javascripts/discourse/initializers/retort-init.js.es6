import { withPluginApi } from "discourse/lib/plugin-api";
import { emojiUrlFor } from "discourse/lib/text";
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

    if (Retort.disableShowForPost(postId)) {
      return;
    }

    Retort.storeWidget(helper);

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
      if (currentUser?.custom_fields?.hide_ignored_retorts) {
        const ignoredUsers = new Set(currentUser.ignored_users);
        displayUsernames = usernames.filter((username) => {
          return !ignoredUsers.has(username);
        });
      }
      if (displayUsernames.length > 0) {
        return helper.attach("retort-toggle", {
          emoji,
          emojiUrl,
          post,
          usernames: displayUsernames,
          currentUser,
        });
      }
      else {
        return null;
      }
    }
    );

    return helper.h("div.post-retort-container", retort_widgets);
  });


  api.addPostClassesCallback((attrs) => {
    if (!Retort.disableShowForPost(attrs.id)) {
      return ["retort"];
    }
  });

  api.modifyClass("route:topic", {
    pluginId: "retort",

    setupController(controller, model) {
      const messageBus = api.container.lookup("message-bus:main");
      Retort.initialize(messageBus, model);
      this._super(controller, model);
    },
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
