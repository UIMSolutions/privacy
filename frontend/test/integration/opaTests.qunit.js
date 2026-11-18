/* global QUnit */
QUnit.config.autostart = false;

sap.ui.getCore().attachInit(function () {
  "use strict";
  sap.ui.require(["uim/gdpr/test/integration/ProjectJourney"], function () {
    QUnit.start();
  });
});
