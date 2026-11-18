sap.ui.define([
  "uim/gdpr/controller/BaseController",
  "sap/ui/model/Filter",
  "sap/ui/model/FilterOperator"
], function (BaseController, Filter, FilterOperator) {
  "use strict";

  return BaseController.extend("uim.gdpr.controller.Main", {
    onSearch: function (oEvent) {
      var sQuery = oEvent.getParameter("query");
      var aFilters = sQuery ? [new Filter({ path: "name", operator: FilterOperator.Contains, value1: sQuery, caseSensitive: false })] : [];
      this.byId("projectsTable").getBinding("items").filter(aFilters);
    },

    onOpenProject: function (oEvent) {
      this.getRouter().navTo("project", { projectId: oEvent.getSource().getBindingContext().getProperty("ID") });
    },

    onCreateProject: function () {
      var that = this;
      this.openFormDialog(this.getText("newProject"), [
        { name: "name", label: this.getText("name"), required: true },
        { name: "controller", label: this.getText("controller") },
        { name: "dpoName", label: this.getText("dpo") },
        { name: "dpoEmail", label: this.getText("dpoEmail"), inputType: "Email" },
        { name: "description", label: this.getText("description"), type: "textarea" }
      ]).then(function (oData) {
        if (!oData) return;
        return that.createIn(that.byId("projectsTable").getBinding("items"), oData).then(function (oContext) {
          that.toast("projectCreated");
          that.getRouter().navTo("project", { projectId: oContext.getProperty("ID") });
        });
      }).catch(this.showError.bind(this));
    }
  });
});
