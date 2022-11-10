import { withPluginApi } from "discourse/lib/plugin-api";
import { emojiUrlFor } from "discourse/lib/text";
import Retort from "../lib/retort";
import User from "discourse/models/user";

function initializePlugin(api) {
  const { retort_enabled } = api.container.lookup("site-settings:main");

  if (!retort_enabled) {
    return;
  }

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
    const currentUser = api.getCurrentUser();
    const retorts = post.retorts
      .map((item) => {
        item.emojiUrl = emojiUrlFor(item.emoji);
        return item;
      })
      .filter(({ emojiUrl }) => emojiUrl)
      .sort((a, b) => a.emoji.localeCompare(b.emoji));
    const retort_widgets = retorts.map(({ emoji, emojiUrl, usernames }) => {
      var displayUsernames = usernames;
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
        })
      }
      else {
        return null;
      }
    }
    );

    return helper.h("div.post-retort-container", retort_widgets);
  });

  api.modifyClass("controller:preferences/notifications", {
    pluginId: "retort",
    actions: {
      save() {
        this.get('saveAttrNames').push('custom_fields')
        this._super()
      }
    }
  })

  api.addPostClassesCallback((attrs) => {
    if (!Retort.disableShowForPost(attrs.id)) {
      return ["retort"];
    }
  });

  if (!User.current()) {
    return;
  }

  api.modifyClass("route:topic", {
    pluginId: "retort",

    setupController(controller, model) {
      const messageBus = api.container.lookup("message-bus:main");
      Retort.initialize(messageBus, model);
      this._super(controller, model);
    },
  });

  api.addPostMenuButton("retort", (attrs) => {
    if (Retort.disableRetortButton(attrs.id)) {
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
    const post = this.findAncestorModel()
    Retort.openPicker(post);
  });

  api.registerConnectorClass("above-footer", "emoji-picker-wrapper", {
    setupComponent(args, component) {
      Retort.setPicker(component);
    }
  })
}

export default {
  name: "retort-button",
  initialize: function () {
    withPluginApi("0.8.6", (api) => initializePlugin(api));
  },
};
