import Object from '@ember/object';
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";

export default Object.create({
  topic: { postStream: { posts: [] } },

  initialize(messageBus, topic) {
    if (this.topic.id) {
      messageBus.unsubscribe(`/retort/topics/${this.topic.id}`);
    }

    this.set("topic", topic);
    messageBus.subscribe(
      `/retort/topics/${this.topic.id}`,
      ({ id, retorts, my_retorts, can_retort, can_remove_retort }) => {
        const post = this.postFor(id);
        if (!post) {
          return;
        }

        post.setProperties({ retorts, my_retorts, can_retort, can_remove_retort });
        this.get(`widgets.${id}`).scheduleRerender();
      }
    );

    const siteSettings = getOwnerWithFallback(this).lookup("site-settings:main");
    this.set("siteSettings", siteSettings);
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
    const categories = this.siteSettings.retort_disabled_categories.split("|");
    return categories.map((cat) => parseInt(cat, 10)).filter(Boolean);
  },

  disableShowForPost(postId) {
    const post = this.postFor(postId);
    if (!post) {
      return true;
    }
    const categoryId = post.get("topic.category.id");
    const disabledCategories = this.disabledCategories();
    return (
      categoryId &&
      disabledCategories.includes(categoryId)
    );
  },

  disableRetortButton(postId) {
    if (this.disableShowForPost(postId)) {return true;}
    if (this.topic.archived) {return true;}
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
      const currentRetortAnchor = document.querySelector(".emoji-picker-anchor.retort");
      if (currentRetortAnchor) {
        currentRetortAnchor.classList.remove("emoji-picker-anchor");
      }
      this.set("picker.isActive", false);
    }
    );
  },

  setPicker(picker) {
    this.set("picker", picker);
    this.set("picker.emojiSelected", (emoji) =>
      this.updateRetort(picker.post, emoji).then(() => {
          picker.set("isActive", false);
          this.localUpdateWidget(picker.post.id, emoji);
        }
      ).catch(popupAjaxError)
    );
  },

  localUpdateWidget(postId, emoji) {
    const currentUser = getOwnerWithFallback(this).lookup("service:current-user");
    const post = this.postFor(postId);
    const widget = this.get(`widgets.${postId}`);
    if (!post || !widget) {
      return;
    }
    const targetRetort = post.retorts.find((retort) => retort.emoji === emoji);
    if (!targetRetort) {
      post.retorts.push({
        post_id: postId,
        emoji,
        usernames: [currentUser.username],
      });
      post.my_retorts.push({
        emoji,
        updated_at: new Date().toISOString(),
      });
    } else {
      const isMyRetort = post.my_retorts?.find((retort) => retort.emoji === emoji) ? true : false;
      if (isMyRetort) {
        //remove username from targetRetort
        const index = targetRetort.usernames.indexOf(currentUser.username);
        targetRetort.usernames.splice(index, 1);
        if (targetRetort.usernames.length <= 0) {
          const retortIndex = post.retorts.findIndex((retort) => retort.emoji === emoji);
          post.retorts.splice(retortIndex, 1);
        }
        //remove retort from my_retorts
        const myRetortIndex = post.my_retorts.findIndex((retort) => retort.emoji === emoji);
        post.my_retorts.splice(myRetortIndex, 1);
      } else {
        targetRetort.usernames.push(currentUser.username);
        post.my_retorts.push({
          emoji,
          updated_at: new Date().toISOString(),
        });
      }
    }
    widget.scheduleRerender();
  }
});
