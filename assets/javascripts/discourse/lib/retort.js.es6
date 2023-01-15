import { ajax } from "discourse/lib/ajax";
import { getOwner } from "discourse-common/lib/get-owner";

export default Ember.Object.create({
  topic: { postStream: { posts: [] } },

  initialize(messageBus, topic) {
    if (this.topic.id) {
      messageBus.unsubscribe(`/retort/topics/${this.topic.id}`);
    }

    this.set("topic", topic);
    messageBus.subscribe(
      `/retort/topics/${this.topic.id}`,
      ({ id, retorts }) => {
        const post = this.postFor(id);
        if (!post) {
          return;
        }

        post.setProperties({ retorts });
        this.get(`widgets.${id}`).scheduleRerender();
      }
    );

    const siteSettings = getOwner(this).lookup("site-settings:main");
    this.set("siteSettings", siteSettings);
  },

  postFor(id) {
    return (this.get("topic.postStream.posts") || []).find((p) => p.id == id);
  },

  storeWidget(helper) {
    if (!this.get("widgets")) {
      this.set("widgets", {});
    }
    this.set(`widgets.${helper.getModel().id}`, helper.widget);
  },

  updateRetort({ id }, retort) {
    return ajax(`/retorts/${id}.json`, {
      type: "POST",
      data: { retort },
    });
  },

  removeRetort({ id }, retort) {
    return ajax(`/retorts/${id}.json`, {
      type: "DELETE",
      data: { retort },
    });
  },

  disabledCategories() {
    const categories = this.siteSettings.retort_disabled_categories.split("|");
    return categories.map((cat) => cat.toLowerCase()).filter(Boolean);
  },

  disableShowForPost(postId) {
    const post = this.postFor(postId);
    if (!post) {
      return true;
    }
    const categoryName = post.get("topic.category.name");
    const disabledCategories = this.disabledCategories();
    return (
      categoryName &&
      disabledCategories.includes(categoryName.toString().toLowerCase())
    );
  },

  disableRetortButton(postId) {
    if (this.disableShowForPost(postId)) return true;
    if (this.topic.archived) return true;
    return false;
  },

  openPicker(post) {
    const retortAnchor = document.querySelector(`
          article[data-post-id="${post.id}"] .post-controls .retort`);
    if (retortAnchor) {
      retortAnchor.classList.add("emoji-picker-anchor")
    }

    this.set("picker.isActive", true);
    this.set("picker.post", post);
    this.set("picker.onEmojiPickerClose", (event) => {
      const retortAnchor = document.querySelector(".emoji-picker-anchor.retort");
      if (retortAnchor) {
        retortAnchor.classList.remove("emoji-picker-anchor")
      }
      this.set("picker.isActive", false);
    }
    );
  },

  setPicker(picker) {
    this.set("picker", picker);
    this.set("picker.emojiSelected", (retort) =>
      this.updateRetort(picker.post, retort).then(() =>
        picker.set("isActive", false)
      )
    );
  },
});
