sap.ui.define([
  "sap/ui/model/json/JSONModel",
  "sap/ui/Device"
], function (JSONModel, Device) {
  "use strict";

  function list(aKeys) {
    return aKeys.map(function (k) { return { key: k }; });
  }

  return {
    createDeviceModel: function () {
      var oModel = new JSONModel(Device);
      oModel.setDefaultBindingMode("OneWay");
      return oModel;
    },

    /** Value lists of the backend enumerations (texts come from i18n via formatter.enumText). */
    createEnumModel: function () {
      return new JSONModel({
        projectStatus: list(["planned", "inProgress", "completed", "archived"]),
        legalBasis: list(["consent", "contract", "legalObligation", "vitalInterests", "publicTask", "legitimateInterests"]),
        activityStatus: list(["draft", "active", "retired"]),
        requestType: list(["access", "rectification", "erasure", "restriction", "portability", "objection"]),
        requestStatus: list(["received", "verified", "inProgress", "completed", "rejected"]),
        severity: list(["low", "medium", "high"]),
        channel: list(["web", "app", "email", "paper", "phone", "other"])
      });
    }
  };
});
