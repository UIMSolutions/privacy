sap.ui.define([
  "sap/ui/test/Opa5",
  "sap/ui/test/matchers/AggregationLengthEquals"
], function (Opa5) {
  "use strict";

  Opa5.createPageObjects({
    onTheMainPage: {
      assertions: {
        iShouldSeeTheProjectsTable: function () {
          return this.waitFor({
            id: "projectsTable",
            viewName: "Main",
            success: function () { Opa5.assert.ok(true, "The projects table is displayed"); },
            errorMessage: "Projects table not found"
          });
        }
      }
    }
  });
});
