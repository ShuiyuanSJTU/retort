import Service, { inject as service } from '@ember/service';
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class Retort extends Service {
  @service appEvents;

  createRetort({ id }, retort) {
    return ajax(`/retorts/${id}.json`, {
      type: "PUT",
      data: { retort },
    });
  }

  withdrawRetort({ id }, retort) {
    return ajax(`/retorts/${id}.json`, {
      type: "DELETE",
      data: { retort },
    });
  }

  removeRetort({ id }, retort) {
    return ajax(`/retorts/${id}/all.json`, {
      type: "DELETE",
      data: { retort },
    });
  }

  disabledCategories() {
    // const siteSettings =
      // getOwnerWithFallback(this).lookup("site-settings:main");
    const categories = this.siteSettings.retort_disabled_categories.split("|");
    return categories.map((cat) => parseInt(cat, 10)).filter(Boolean);
  }

  disableShowForTopic(topic) {
    if (!topic) {
      return true;
    }
    const categoryId = topic.get("category.id");
    const disabledCategories = this.disabledCategories();
    return categoryId && disabledCategories.includes(categoryId);
  }

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
  }

  setPicker(picker) {
    this.set("picker", picker);
    this.set("picker.emojiSelected", (emoji) =>
      this.createRetort(picker.post, emoji)
        .then((data) => {
          picker.set("isActive", false);
          if (data.id !== picker.post.id) {
            // eslint-disable-next-line no-console
            console.error("Retort post id mismatch");
          } else {
            picker.post.set("retorts", data.retorts);
            // getOwnerWithFallback(this).lookup("service:app-events")
            this.appEvents.trigger("post-stream:refresh", { id: data.id });
          }
        })
        .catch(popupAjaxError)
    );
  }
}
