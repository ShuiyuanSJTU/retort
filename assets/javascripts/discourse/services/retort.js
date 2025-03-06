import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

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
}
