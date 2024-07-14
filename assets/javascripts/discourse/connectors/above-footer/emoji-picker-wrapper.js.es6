import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
export default {
  setupComponent(args, component) {
    const retort = getOwnerWithFallback(component).lookup("service:retort");
    retort.setPicker(component);
  },
};
