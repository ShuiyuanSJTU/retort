import Object from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";

export default Object.create({
  topic: { postStream: { posts: [] } },

  activate(topic) {
    const messageBus = getOwnerWithFallback(this).lookup("service:message-bus");
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
  },

  deactivate() {
    const messageBus = getOwnerWithFallback(this).lookup("service:message-bus");
    if (this.topic.id) {
      messageBus.unsubscribe(`/retort/topics/${this.topic.id}`);
    }
    this.set("topic", { postStream: { posts: [] } });
    this.set("widgets", {});
  },

  postFor(id) {
    return (this.get("topic.postStream.posts") || []).find((p) => p.id === id);
  },

  storeWidget(id, widget) {
    if (!this.get("widgets")) {
      this.set("widgets", {});
    }
    this.set(`widgets.${id}`, widget);
  },

  removeStoredWidget(id) {
    if (!this.get(`widgets.${id}`)) {
      return;
    }
    delete this.get("widgets")[id];
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
    const siteSettings =
      getOwnerWithFallback(this).lookup("site-settings:main");
    const categories = siteSettings.retort_disabled_categories.split("|");
    return categories.map((cat) => parseInt(cat, 10)).filter(Boolean);
  },

  disableShowForPost(postId) {
    const post = this.postFor(postId);
    if (!post) {
      return true;
    }
    const categoryId = post.get("topic.category.id");
    const disabledCategories = this.disabledCategories();
    return categoryId && disabledCategories.includes(categoryId);
  },

  disableRetortButton(postId) {
    if (this.disableShowForPost(postId)) {
      return true;
    }
    if (this.topic.archived) {
      return true;
    }
    return false;
  },

  openPicker(post) {
    const retortAnchor = document.querySelector(`
          article[data-post-id="${post.id}"] .post-controls .retort`);
    if (retortAnchor) {
      retortAnchor.classList.add("emoji-picker-anchor");
    }

    this.set("picker.isActive", true);
    this.set("picker.post", post);
    // eslint-disable-next-line no-unused-vars
    this.set("picker.onEmojiPickerClose", (event) => {
      const currentRetortAnchor = document.querySelector(
        ".emoji-picker-anchor.retort"
      );
      if (currentRetortAnchor) {
        currentRetortAnchor.classList.remove("emoji-picker-anchor");
      }
      this.set("picker.isActive", false);
    });
  },

  setPicker(picker) {
    this.set("picker", picker);
    this.set("picker.emojiSelected", (emoji) =>
      this.updateRetort(picker.post, emoji)
        .then(() => {
          picker.set("isActive", false);
          this.localUpdateWidget(picker.post.id, emoji);
        })
        .catch(popupAjaxError)
    );
  },

  localUpdateWidget(postId, emoji) {
    const currentUser = getOwnerWithFallback(this).lookup(
      "service:current-user"
    );
    const post = this.postFor(postId);
    const widget = this.get(`widgets.${postId}`);
    if (!post || !widget || !currentUser) {
      return;
    }
    const targetRetort = post.retorts.find((retort) => retort.emoji === emoji);
    const isMyRetort = post.my_retorts?.any((retort) => retort.emoji === emoji);
    if (isMyRetort) {
      //remove username from targetRetort
      if (
        targetRetort &&
        targetRetort.usernames.includes(currentUser.username)
      ) {
        // check if username already exists in targetRetort
        // this may caused by messagebus update too fast
        const index = targetRetort.usernames.indexOf(currentUser.username);
        targetRetort.usernames.splice(index, 1);
        if (targetRetort.usernames.length <= 0) {
          const retortIndex = post.retorts.findIndex(
            (retort) => retort.emoji === emoji
          );
          post.retorts.splice(retortIndex, 1);
        }
      }
      //remove retort from my_retorts
      const myRetortIndex = post.my_retorts.findIndex(
        (retort) => retort.emoji === emoji
      );
      post.my_retorts.splice(myRetortIndex, 1);
    } else {
      post.my_retorts.push({
        emoji,
        updated_at: new Date().toISOString(),
      });
      if (!targetRetort) {
        post.retorts.push({
          post_id: postId,
          emoji,
          usernames: [currentUser.username],
        });
      } else {
        if (!targetRetort.usernames.includes(currentUser.username)) {
          // check if username already exists in targetRetort
          // this may caused by messagebus update too fast
          targetRetort.usernames.push(currentUser.username);
        }
      }
    }
    widget.scheduleRerender();
  },
});
