/* global QUnit, opaTest */
sap.ui.define([
  "sap/ui/test/opaQunit",
  "sap/ui/test/Opa5",
  "./pages/Main"
], function (opaTest, Opa5) {
  "use strict";

  Opa5.extendConfig({ viewNamespace: "uim.gdpr.view.", autoWait: true });
  QUnit.module("Projects");

  opaTest("shows the list of GDPR projects", function (Given, When, Then) {
    Given.iStartMyUIComponent({ componentConfig: { name: "uim.gdpr" } });
    Then.onTheMainPage.iShouldSeeTheProjectsTable();
    Then.iTeardownMyUIComponent();
  });
});
