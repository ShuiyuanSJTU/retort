import { withPluginApi } from "discourse/lib/plugin-api";
import { emojiUrlFor } from "discourse/lib/text";
import discourseLater from "discourse-common/lib/later";
import { schedule } from "@ember/runloop";
import {
  default as computed,
  observes,
} from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import { createPopper } from "@popperjs/core";
import Retort from "../lib/retort";
import User from "discourse/models/user";

function initializePlugin(api) {
  const { retort_enabled, retort_allowed_emojis } =
    api.container.lookup("site-settings:main");
  const messageBus = api.container.lookup("message-bus:main");

  if (!retort_enabled) {
    return;
  }

  api.decorateWidget("post-contents:after-cooked", (helper) => {
    let postId = helper.getModel().id;
    let post = Retort.postFor(postId);

    if (Retort.disabledFor(postId)) {
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
    if (!Retort.disabledFor(attrs.id)) {
      return ["retort"];
    }
  });

  if (!User.current()) {
    return;
  }

  api.modifyClass("route:topic", {
    pluginId: "retort",

    setupController(controller, model) {
      Retort.initialize(messageBus, model);

      this._super(controller, model);
    },
  });

  api.addPostMenuButton("retort", (attrs) => {
    if (Retort.disabledFor(attrs.id)) {
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
    Retort.openPicker(this.findAncestorModel());
  });

  api.modifyClass("component:emoji-picker", {
    pluginId: "retort",

    @action
  onCategorySelection(sectionName) {
    const section = document.querySelector(
      `.emoji-picker-emoji-area .section[data-section="${sectionName}"]`
    );
    section &&
      section.scrollIntoView({
        behavior: "smooth",
        block: "nearest",
        inline: "start",
      });
  },

  @computed("retort", "isActive")
  activeRetort() {
    return this.retort && this.isActive;
  },

  @observes("isActive")
  _setup() {
    if (this.retort) {
      this._setupRetort();
    } else {
      this._super();
    }
  },

  _setupRetort() {
    if (this.isActive) {
      this.onShowRetort();
    } else {
      this.onClose();
    }
  },

  // See onShow in emoj-picker for logic pattern
  @action
  onShowRetort() {
    this.set("recentEmojis", this.emojiStore.favorites);

    schedule("afterRender", () => {
      this._applyFilter(this.initialFilter);
      document.addEventListener("click", this.handleOutsideClick);

      const post = this.post;
      const emojiPicker = document.querySelector(".emoji-picker");
      const retortButton = document.querySelector(`
          article[data-post-id="${post.id}"] .post-controls .retort`);

      if (!emojiPicker || !retortButton) return false;

      const popperAnchor = retortButton;

      if (!this.site.isMobileDevice && this.usePopper && popperAnchor) {
        const modifiers = [
          {
            name: "preventOverflow",
          },
          {
            name: "offset",
            options: {
              offset: [5, 5],
            },
          },
        ];

        if (
          this.placement === "auto" &&
          window.innerWidth < popperAnchor.clientWidth * 2
        ) {
          modifiers.push({
            name: "computeStyles",
            enabled: true,
            fn({ state }) {
              state.styles.popper = {
                ...state.styles.popper,
                position: "fixed",
                left: `${(window.innerWidth - state.rects.popper.width) / 2
                  }px`,
                top: "50%",
                transform: "translateY(-50%)",
              };

              return state;
            },
          });
        }
        this._popper = createPopper(popperAnchor, emojiPicker, {
          placement: this.placement,
        });
      }

      const emojis = retort_allowed_emojis.split("|");
      if (emojis.length > 0) {
        const suggestedSection = document.createElement("div");
        suggestedSection.setAttribute("class", "section");
        suggestedSection.setAttribute("data-section", "retort");
        suggestedSection.innerHTML = `
              <div class="section-header">
                <span class="title">${I18n.t("retort.section.title")}</span>
              </div>
              <div class="section-group">
              ${emojis
            .map(
              (code) => `<img
                src="${emojiUrlFor(code)}"
                width=20
                height=20
                loading="lazy"
                title='${code}'
                alt='${code}'
                class='emoji' />`
            )
            .join("")}
              </div>
            `;
        const emojiContainer = emojiPicker.querySelector(".emojis-container");
        emojiContainer.insertBefore(
          suggestedSection,
          emojiContainer.firstChild
        );

        const sectionButton = document.createElement("button");
        sectionButton.setAttribute("data-section", "retort");
        sectionButton.setAttribute(
          "class",
          "btn btn-default category-button emoji"
        );
        sectionButton.setAttribute("type", "button");
        sectionButton.onclick = () => {
          this.onCategorySelection("retort");
        };
        const firstEmoji = emojis[0];
        sectionButton.innerHTML = `<img width="20" height="20" src="${emojiUrlFor(
          firstEmoji
        )}" title="${firstEmoji}" alt="${firstEmoji}" class="emoji">`;
        const emojiCategoryButtons = emojiPicker.querySelector(
          ".emoji-picker-category-buttons"
        );
        emojiCategoryButtons.insertBefore(
          sectionButton,
          emojiCategoryButtons.firstChild
        );
      }

      // this is a low-tech trick to prevent appending hundreds of emojis
      // of blocking the rendering of the picker
      discourseLater(() => {
        schedule("afterRender", () => {
          if (!this.site.isMobileDevice || this.isEditorFocused) {
            const filter = emojiPicker.querySelector("input.filter");
            filter && filter.focus();

            if (this._sectionObserver) {
              emojiPicker
                .querySelectorAll(
                  ".emojis-container .section .section-header"
                )
                .forEach((p) => this._sectionObserver.observe(p));
            }
          }

          if (this.selectedDiversity !== 0) {
            this._applyDiversity(this.selectedDiversity);
          }
        });
      }, 50);
    });
  },
});
}

export default {
  name: "retort-button",
  initialize: function () {
    withPluginApi("0.8.6", (api) => initializePlugin(api));
  },
};
