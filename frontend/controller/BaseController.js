sap.ui.define([
  "sap/ui/core/mvc/Controller",
  "sap/ui/core/routing/History",
  "sap/m/MessageToast",
  "sap/m/MessageBox",
  "sap/m/Dialog",
  "sap/m/Button",
  "sap/m/Label",
  "sap/m/Input",
  "sap/m/TextArea",
  "sap/m/Select",
  "sap/m/CheckBox",
  "sap/m/DatePicker",
  "sap/m/DateTimePicker",
  "sap/m/StepInput",
  "sap/ui/core/Item",
  "sap/ui/layout/form/SimpleForm",
  "uim/gdpr/model/formatter"
], function (Controller, History, MessageToast, MessageBox, Dialog, Button, Label, Input, TextArea, Select, CheckBox,
  DatePicker, DateTimePicker, StepInput, Item, SimpleForm, formatter) {
  "use strict";

  return Controller.extend("uim.gdpr.controller.BaseController", {
    formatter: formatter,

    getRouter: function () { return this.getOwnerComponent().getRouter(); },

    getModel: function (sName) {
      return this.getView().getModel(sName) || this.getOwnerComponent().getModel(sName);
    },

    getText: function (sKey, aArgs) {
      return this.getOwnerComponent().getModel("i18n").getResourceBundle().getText(sKey, aArgs);
    },

    toast: function (sKey, aArgs) { MessageToast.show(this.getText(sKey, aArgs)); },

    /** Shows the backend error message (OData error payload) of a failed request. */
    showError: function (oError) {
      var sMessage = (oError && oError.error && oError.error.message) || (oError && oError.message) || String(oError);
      MessageBox.error(sMessage);
    },

    onNavBack: function () {
      if (History.getInstance().getPreviousHash() !== undefined) {
        window.history.go(-1);
      } else {
        this.getRouter().navTo("main", {}, true);
      }
    },

    /**
     * Calls an unbound OData action (e.g. "ExtendRequest") with parameters and
     * resolves with the returned entity data.
     */
    callAction: function (sName, mParameters) {
      var oOperation = this.getModel().bindContext("/" + sName + "(...)");
      Object.keys(mParameters).forEach(function (k) {
        if (mParameters[k] !== undefined && mParameters[k] !== "") oOperation.setParameter(k, mParameters[k]);
      });
      return oOperation.execute().then(function () {
        return oOperation.getBoundContext().getObject();
      });
    },

    /**
     * Opens a generic create dialog. aFields: [{ name, label, type: text|textarea|select|bool|date|datetime|int,
     * enumName, required, value }]. Resolves with the entered values (only non-empty ones).
     */
    openFormDialog: function (sTitle, aFields) {
      var that = this;
      var oEnums = this.getModel("enums");
      return new Promise(function (resolve) {
        var mControls = {};
        var aContent = [];
        aFields.forEach(function (f) {
          var oControl;
          switch (f.type) {
            case "textarea": oControl = new TextArea({ rows: 3, width: "100%", value: f.value }); break;
            case "bool": oControl = new CheckBox({ selected: !!f.value }); break;
            case "date": oControl = new DatePicker({ valueFormat: "yyyy-MM-dd", value: f.value }); break;
            case "datetime": oControl = new DateTimePicker({ valueFormat: "yyyy-MM-dd'T'HH:mm:ssXXX" }); break;
            case "int": oControl = new StepInput({ min: 0, value: f.value || 0 }); break;
            case "select":
              oControl = new Select({ width: "100%", forceSelection: !f.optional });
              if (f.optional) oControl.addItem(new Item({ key: "", text: "–" }));
              (f.items || oEnums.getProperty("/" + f.enumName)).forEach(function (e) {
                oControl.addItem(new Item({ key: e.key, text: e.text || formatter.enumText.call(that, e.key) }));
              });
              if (f.value) oControl.setSelectedKey(f.value);
              break;
            default: oControl = new Input({ value: f.value, type: f.inputType || "Text" });
          }
          mControls[f.name] = oControl;
          aContent.push(new Label({ text: f.label, required: !!f.required, labelFor: oControl }), oControl);
        });

        var oDialog = new Dialog({
          title: sTitle,
          contentWidth: "36rem",
          content: [new SimpleForm({ editable: true, layout: "ResponsiveGridLayout", content: aContent })],
          beginButton: new Button({
            type: "Emphasized",
            text: that.getText("ok"),
            press: function () {
              var oData = {};
              aFields.forEach(function (f) {
                var c = mControls[f.name];
                var v = f.type === "bool" ? c.getSelected()
                  : f.type === "select" ? c.getSelectedKey()
                  : f.type === "int" ? c.getValue()
                  : c.getValue();
                if (v !== "" && v !== null && v !== undefined) oData[f.name] = v;
              });
              oDialog.close();
              resolve(oData);
            }
          }),
          endButton: new Button({ text: that.getText("cancel"), press: function () { oDialog.close(); resolve(null); } }),
          afterClose: function () { oDialog.destroy(); }
        });
        that.getView().addDependent(oDialog);
        oDialog.open();
      });
    },

    /** Creates an entity in a list binding; resolves with the created context. */
    createIn: function (oListBinding, oData) {
      var oContext = oListBinding.create(oData, true);
      return oContext.created().then(function () { return oContext; }, function (oError) {
        if (!oError.canceled) oContext.delete().catch(function () { /* transient context already gone */ });
        throw oError;
      });
    }
  });
});
