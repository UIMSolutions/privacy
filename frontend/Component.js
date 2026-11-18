sap.ui.define([
  "sap/ui/core/UIComponent",
  "sap/ui/core/Messaging",
  "uim/gdpr/model/models"
], function (UIComponent, Messaging, models) {
  "use strict";

  return UIComponent.extend("uim.gdpr.Component", {
    metadata: {
      manifest: "json",
      interfaces: ["sap.ui.core.IAsyncContentCreation"]
    },

    init: function () {
      UIComponent.prototype.init.apply(this, arguments);
      this.setModel(models.createDeviceModel(), "device");
      this.setModel(models.createEnumModel(), "enums");
      this.setModel(Messaging.getMessageModel(), "message");
      this.getRouter().initialize();
    }
  });
});
