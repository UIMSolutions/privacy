/* global QUnit */
sap.ui.define([
  "uim/gdpr/model/formatter",
  "sap/ui/core/library"
], function (formatter, coreLibrary) {
  "use strict";
  var ValueState = coreLibrary.ValueState;

  QUnit.module("formatter");

  QUnit.test("state", function (assert) {
    assert.strictEqual(formatter.state("high"), ValueState.Error);
    assert.strictEqual(formatter.state("completed"), ValueState.Success);
    assert.strictEqual(formatter.state("inProgress"), ValueState.Warning);
    assert.strictEqual(formatter.state("retired"), ValueState.None);
  });

  QUnit.test("scoreState", function (assert) {
    assert.strictEqual(formatter.scoreState(90), ValueState.Success);
    assert.strictEqual(formatter.scoreState(60), ValueState.Warning);
    assert.strictEqual(formatter.scoreState(10), ValueState.Error);
  });

  QUnit.test("daysLeft", function (assert) {
    assert.strictEqual(formatter.daysLeft(3, "received"), "3 day(s) left");
    assert.strictEqual(formatter.daysLeft(-2, "inProgress"), "2 day(s) overdue");
    assert.strictEqual(formatter.daysLeft(-2, "completed"), "");
  });

  QUnit.test("authorityText", function (assert) {
    assert.strictEqual(formatter.authorityText(false, null, 0), "not required");
    assert.strictEqual(formatter.authorityText(true, null, 10), "10 h left");
    assert.strictEqual(formatter.authorityText(true, null, -5), "5 h overdue");
  });
});
