sap.ui.define([
  "sap/ui/core/library"
], function (coreLibrary) {
  "use strict";
  var ValueState = coreLibrary.ValueState;

  var formatter = {
    /** ValueState for status / level / severity values. */
    state: function (sValue) {
      switch (sValue) {
        case "completed": case "active": case "low": case "closed": case "verified": return ValueState.Success;
        case "inProgress": case "medium": case "received": case "reported": case "planned": return ValueState.Warning;
        case "high": case "rejected": case "open": return ValueState.Error;
        default: return ValueState.None;
      }
    },

    /** ValueState for the compliance score (0–100). */
    scoreState: function (fScore) {
      if (fScore === null || fScore === undefined) return ValueState.None;
      return fScore >= 80 ? ValueState.Success : fScore >= 50 ? ValueState.Warning : ValueState.Error;
    },

    /** i18n text of an enum value: key "enum.<value>", falls back to the value. */
    enumText: function (sValue) {
      if (!sValue) return "";
      var oBundle = this.getOwnerComponent ? this.getOwnerComponent().getModel("i18n").getResourceBundle() : null;
      var sKey = "enum." + sValue;
      return oBundle && oBundle.hasText(sKey) ? oBundle.getText(sKey) : sValue;
    },

    /** "5 days left" / "3 days overdue" for open requests. */
    daysLeft: function (iDays, sStatus) {
      if (sStatus === "completed" || sStatus === "rejected") return "";
      if (iDays === 0) return "due today";
      return iDays > 0 ? iDays + " day(s) left" : (-iDays) + " day(s) overdue";
    },

    /** Breach notification status. */
    authorityText: function (bRequired, sReportedAt, iHoursLeft) {
      if (!bRequired) return "not required";
      if (sReportedAt) return "reported " + formatter.timestamp(sReportedAt);
      return iHoursLeft >= 0 ? iHoursLeft + " h left" : (-iHoursLeft) + " h overdue";
    },

    /** ISO timestamp → locale date + time. */
    timestamp: function (sIso) {
      if (!sIso) return "";
      var d = new Date(sIso);
      return isNaN(d) ? sIso : d.toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
    },

    isOpenRequest: function (sStatus) { return sStatus !== "completed" && sStatus !== "rejected"; }
  };
  return formatter;
});
