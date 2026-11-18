sap.ui.define([
  "uim/gdpr/controller/BaseController",
  "sap/ui/model/json/JSONModel",
  "sap/ui/model/Filter",
  "sap/ui/model/FilterOperator",
  "sap/m/MessageBox"
], function (BaseController, JSONModel, Filter, FilterOperator, MessageBox) {
  "use strict";

  return BaseController.extend("uim.gdpr.controller.Project", {
    onInit: function () {
      this.getView().setModel(new JSONModel({}), "report");
      this.getRouter().getRoute("project").attachPatternMatched(this._onMatched, this);
    },

    _onMatched: function (oEvent) {
      this._sProjectId = oEvent.getParameter("arguments").projectId;
      this.getView().bindElement({ path: "/Projects('" + encodeURIComponent(this._sProjectId) + "')" });
      this._loadReport();
    },

    /** Calls the function import GetProjectReport and puts the result into the "report" JSON model. */
    _loadReport: function () {
      var oView = this.getView();
      var oBinding = this.getModel().bindContext("/GetProjectReport(projectId='" + this._sProjectId.replace(/'/g, "''") + "')");
      oBinding.requestObject().then(function (oReport) {
        oView.getModel("report").setData(oReport || {});
      }).catch(this.showError.bind(this));
    },

    /** Refreshes the project, its registers and the report after a change. */
    _refresh: function () {
      var oBinding = this.getView().getElementBinding();
      if (oBinding) oBinding.refresh();
      this._loadReport();
    },

    _run: function (oPromise, sToastKey) {
      var that = this;
      return oPromise.then(function (r) {
        if (r === null) return;
        if (sToastKey) that.toast(sToastKey);
        that._refresh();
      }).catch(this.showError.bind(this));
    },

    _create: function (sTableId, sTitle, aFields) {
      var that = this;
      this._run(this.openFormDialog(sTitle, aFields).then(function (oData) {
        if (!oData) return null;
        return that.createIn(that.byId(sTableId).getBinding("items"), oData);
      }), "saved");
    },

    onTab: function (oEvent) { this.byId("tabs").setSelectedKey(oEvent.getSource().data("key")); },

    // ------------------------------------------------------------ project

    onEditProject: function () {
      var oContext = this.getView().getBindingContext();
      this._run(this.openFormDialog(this.getText("edit"), [
        { name: "name", label: this.getText("name"), required: true, value: oContext.getProperty("name") },
        { name: "controller", label: this.getText("controller"), value: oContext.getProperty("controller") },
        { name: "dpoName", label: this.getText("dpo"), value: oContext.getProperty("dpoName") },
        { name: "dpoEmail", label: this.getText("dpoEmail"), value: oContext.getProperty("dpoEmail") },
        { name: "status", label: this.getText("status"), type: "select", enumName: "projectStatus", value: oContext.getProperty("status") },
        { name: "description", label: this.getText("description"), type: "textarea", value: oContext.getProperty("description") }
      ]).then(function (oData) {
        if (!oData) return null;
        return Promise.all(Object.keys(oData).map(function (k) { return oContext.setProperty(k, oData[k]); }));
      }), "saved");
    },

    onDeleteProject: function () {
      var that = this;
      MessageBox.confirm(this.getText("confirmDeleteProject"), {
        onClose: function (sAction) {
          if (sAction !== MessageBox.Action.OK) return;
          that.getView().getBindingContext().delete().then(function () {
            that.getRouter().navTo("main", {}, true);
          }).catch(that.showError.bind(that));
        }
      });
    },

    /** Deletes the entity of the pressed table row. */
    onDelete: function (oEvent) {
      var oContext = oEvent.getSource().getBindingContext();
      var that = this;
      MessageBox.confirm(this.getText("confirmDelete"), {
        onClose: function (sAction) {
          if (sAction === MessageBox.Action.OK) that._run(oContext.delete(), "deleted");
        }
      });
    },

    // ------------------------------------------------------------ activities

    _activityFields: function (c) {
      var g = function (n) { return c ? c.getProperty(n) : undefined; };
      return [
        { name: "name", label: this.getText("name"), required: true, value: g("name") },
        { name: "purpose", label: this.getText("purpose"), type: "textarea", value: g("purpose") },
        { name: "legalBasis", label: this.getText("legalBasis"), type: "select", enumName: "legalBasis", value: g("legalBasis") || "contract" },
        { name: "dataCategories", label: this.getText("dataCategories"), value: g("dataCategories") },
        { name: "dataSubjects", label: this.getText("dataSubjects"), value: g("dataSubjects") },
        { name: "recipients", label: this.getText("recipients"), value: g("recipients") },
        { name: "retentionPeriod", label: this.getText("retentionPeriod"), value: g("retentionPeriod") },
        { name: "toms", label: "TOMs (Art. 32)", type: "textarea", value: g("toms") },
        { name: "specialCategories", label: this.getText("specialCategories"), type: "bool", value: g("specialCategories") },
        { name: "largeScale", label: this.getText("largeScale"), type: "bool", value: g("largeScale") },
        { name: "systematicMonitoring", label: this.getText("systematicMonitoring"), type: "bool", value: g("systematicMonitoring") },
        { name: "automatedDecisions", label: this.getText("automatedDecisions"), type: "bool", value: g("automatedDecisions") },
        { name: "thirdCountryTransfer", label: this.getText("thirdCountryTransfer"), type: "bool", value: g("thirdCountryTransfer") },
        { name: "transferSafeguard", label: this.getText("transferSafeguard"), value: g("transferSafeguard") },
        { name: "dpiaCompleted", label: this.getText("dpiaCompleted"), type: "bool", value: g("dpiaCompleted") }
      ];
    },

    onCreateActivity: function () {
      this._create("activitiesTable", this.getText("newActivity"), this._activityFields(null));
    },

    onEditActivity: function (oEvent) {
      var oContext = oEvent.getSource().getBindingContext();
      var aFields = this._activityFields(oContext);
      this._run(this.openFormDialog(this.getText("edit"), aFields).then(function (oData) {
        if (!oData) return null;
        // booleans are always sent (unchecked = false)
        aFields.forEach(function (f) { if (f.type === "bool" && oData[f.name] === undefined) oData[f.name] = false; });
        return Promise.all(Object.keys(oData).map(function (k) { return oContext.setProperty(k, oData[k]); }));
      }), "saved");
    },

    onActivate: function (oEvent) {
      this._run(oEvent.getSource().getBindingContext().setProperty("status", "active"), "saved");
    },

    // ------------------------------------------------------------ requests

    onCreateRequest: function () {
      this._create("requestsTable", this.getText("newRequest"), [
        { name: "type", label: this.getText("right"), type: "select", enumName: "requestType" },
        { name: "subjectName", label: this.getText("dataSubject"), required: true },
        { name: "subjectEmail", label: this.getText("email"), inputType: "Email" },
        { name: "receivedOn", label: this.getText("received"), type: "date" },
        { name: "description", label: this.getText("description"), type: "textarea" }
      ]);
    },

    onExtendRequest: function (oEvent) {
      var sId = oEvent.getSource().getBindingContext().getProperty("ID");
      var that = this;
      this._run(this.openFormDialog(this.getText("extend"), [
        { name: "reason", label: this.getText("reason"), required: true, type: "textarea" }
      ]).then(function (oData) {
        return oData ? that.callAction("ExtendRequest", { requestId: sId, reason: oData.reason || "" }) : null;
      }), "saved");
    },

    onCloseRequest: function (oEvent) {
      var oContext = oEvent.getSource().getBindingContext();
      this._run(this.openFormDialog(this.getText("closeRequest"), [
        { name: "status", label: this.getText("status"), type: "select", items: [{ key: "completed" }, { key: "rejected" }] },
        { name: "resolution", label: this.getText("resolution"), required: true, type: "textarea" }
      ]).then(function (oData) {
        if (!oData) return null;
        // resolution first: the status change requires it
        return oContext.setProperty("resolution", oData.resolution || "").then(function () {
          return oContext.setProperty("status", oData.status);
        });
      }), "saved");
    },

    // ------------------------------------------------------------ breaches

    onCreateBreach: function () {
      this._create("breachesTable", this.getText("recordBreach"), [
        { name: "title", label: this.getText("title"), required: true },
        { name: "description", label: this.getText("description"), type: "textarea" },
        { name: "detectedAt", label: this.getText("detected"), type: "datetime" },
        { name: "severity", label: this.getText("risk"), type: "select", enumName: "severity", value: "medium" },
        { name: "affectedSubjects", label: this.getText("affected"), type: "int" },
        { name: "dataCategories", label: this.getText("dataCategories") },
        { name: "measures", label: this.getText("measures"), type: "textarea" }
      ]);
    },

    onEditBreach: function (oEvent) {
      var oContext = oEvent.getSource().getBindingContext();
      this._run(this.openFormDialog(this.getText("measures"), [
        { name: "severity", label: this.getText("risk"), type: "select", enumName: "severity", value: oContext.getProperty("severity") },
        { name: "affectedSubjects", label: this.getText("affected"), type: "int", value: oContext.getProperty("affectedSubjects") },
        { name: "measures", label: this.getText("measures"), type: "textarea", value: oContext.getProperty("measures") }
      ]).then(function (oData) {
        if (!oData) return null;
        return Promise.all(Object.keys(oData).map(function (k) { return oContext.setProperty(k, oData[k]); }));
      }), "saved");
    },

    /** ReportBreach / NotifyBreachSubjects / CloseBreach (action name in custom data "action"). */
    onBreachAction: function (oEvent) {
      var sAction = oEvent.getSource().data("action");
      var sId = oEvent.getSource().getBindingContext().getProperty("ID");
      this._run(this.callAction(sAction, { breachId: sId }), "saved");
    },

    // ------------------------------------------------------------ consents

    onCreateConsent: function () {
      this._create("consentsTable", this.getText("newConsent"), [
        { name: "subjectEmail", label: this.getText("email"), required: true, inputType: "Email" },
        { name: "purpose", label: this.getText("purpose"), required: true },
        { name: "textVersion", label: this.getText("version") },
        { name: "channel", label: this.getText("channel"), type: "select", enumName: "channel" },
        { name: "givenAt", label: this.getText("given"), type: "datetime" }
      ]);
    },

    onWithdrawConsent: function (oEvent) {
      var sId = oEvent.getSource().getBindingContext().getProperty("ID");
      this._run(this.callAction("WithdrawConsent", { consentId: sId }), "saved");
    },

    onSearchConsent: function (oEvent) {
      var sQuery = oEvent.getParameter("query");
      this.byId("consentsTable").getBinding("items").filter(sQuery
        ? [new Filter({ path: "subjectEmail", operator: FilterOperator.Contains, value1: sQuery, caseSensitive: false })] : []);
    }
  });
});
