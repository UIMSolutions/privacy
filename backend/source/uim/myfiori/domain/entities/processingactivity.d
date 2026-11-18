/// Entry of the record of processing activities (RoPA, Art. 30 GDPR).
module uim.myfiori.domain.entities.processingactivity;

@safe:

import std.datetime.systime : SysTime;
import uim.myfiori.domain.entities.base;
import uim.myfiori.domain.enumerations;
import uim.myfiori.domain.exceptions;
import uim.myfiori.domain.services.dpia;
import uim.myfiori.domain.types;

class DProcessingActivity : DEntity {
  private EntityId _projectId;
  private string _name;
  private string _purpose;                // Art. 30 (1) b
  private LegalBasis _legalBasis;         // Art. 6
  private string _dataCategories;         // Art. 30 (1) c
  private string _dataSubjects;           // Art. 30 (1) c
  private string _recipients;             // Art. 30 (1) d
  private string _retentionPeriod;        // Art. 30 (1) f
  private string _toms;                   // Art. 30 (1) g / Art. 32
  private bool _specialCategories;        // Art. 9 / 10
  private bool _largeScale;
  private bool _systematicMonitoring;
  private bool _automatedDecisions;       // Art. 22
  private bool _thirdCountryTransfer;     // Art. 44 ff.
  private string _transferSafeguard;      // e.g. adequacy decision, SCC, BCR
  private bool _dpiaCompleted;            // Art. 35
  private ActivityStatus _status;

  this(EntityId id, EntityId projectId, string name, string purpose, LegalBasis legalBasis,
      string dataCategories, string dataSubjects, string recipients, string retentionPeriod, string toms,
      bool specialCategories, bool largeScale, bool systematicMonitoring, bool automatedDecisions,
      bool thirdCountryTransfer, string transferSafeguard, bool dpiaCompleted, ActivityStatus status,
      SysTime createdAt, SysTime modifiedAt) {
    super(id, createdAt, modifiedAt);
    if (projectId.length == 0) throw new ValidationException("Processing activity requires a project");
    _projectId = projectId;
    _name = requireText(name, "Activity name");
    _purpose = limitText(purpose, "Purpose");
    _legalBasis = legalBasis;
    _dataCategories = limitText(dataCategories, "Data categories");
    _dataSubjects = limitText(dataSubjects, "Data subject categories");
    _recipients = limitText(recipients, "Recipients");
    _retentionPeriod = limitText(retentionPeriod, "Retention period", 500);
    _toms = limitText(toms, "Technical and organisational measures");
    _specialCategories = specialCategories;
    _largeScale = largeScale;
    _systematicMonitoring = systematicMonitoring;
    _automatedDecisions = automatedDecisions;
    _thirdCountryTransfer = thirdCountryTransfer;
    _transferSafeguard = limitText(transferSafeguard, "Transfer safeguard", 500);
    _dpiaCompleted = dpiaCompleted;
    _status = status;
    if (_status == ActivityStatus.active) ensureComplete;
  }

  /// New activities start as draft.
  static DProcessingActivity create(EntityId id, EntityId projectId, string name, string purpose, LegalBasis legalBasis) {
    auto t = now;
    return new DProcessingActivity(id, projectId, name, purpose, legalBasis, "", "", "", "", "",
        false, false, false, false, false, "", false, ActivityStatus.draft, t, t);
  }

  EntityId projectId() const pure nothrow { return _projectId; }
  string name() const pure nothrow { return _name; }
  string purpose() const pure nothrow { return _purpose; }
  LegalBasis legalBasis() const pure nothrow { return _legalBasis; }
  string dataCategories() const pure nothrow { return _dataCategories; }
  string dataSubjects() const pure nothrow { return _dataSubjects; }
  string recipients() const pure nothrow { return _recipients; }
  string retentionPeriod() const pure nothrow { return _retentionPeriod; }
  string toms() const pure nothrow { return _toms; }
  bool specialCategories() const pure nothrow { return _specialCategories; }
  bool largeScale() const pure nothrow { return _largeScale; }
  bool systematicMonitoring() const pure nothrow { return _systematicMonitoring; }
  bool automatedDecisions() const pure nothrow { return _automatedDecisions; }
  bool thirdCountryTransfer() const pure nothrow { return _thirdCountryTransfer; }
  string transferSafeguard() const pure nothrow { return _transferSafeguard; }
  bool dpiaCompleted() const pure nothrow { return _dpiaCompleted; }
  ActivityStatus status() const pure nothrow { return _status; }

  /// DPIA screening (Art. 35) derived from the risk criteria.
  DpiaAssessment assessment() const pure nothrow {
    return assessDpia(DpiaCriteria(_specialCategories, _largeScale, _systematicMonitoring,
        _automatedDecisions, _thirdCountryTransfer));
  }

  RiskLevel riskLevel() const pure nothrow { return assessment.riskLevel; }
  bool dpiaRequired() const pure nothrow { return assessment.dpiaRequired; }

  /// Transfer to a third country without documented safeguard (Chapter V).
  bool transferWithoutSafeguard() const pure nothrow { return _thirdCountryTransfer && _transferSafeguard.length == 0; }

  // ------------------------------------------------------------ business methods

  void rename(string v) { _name = requireText(v, "Activity name"); changed; }
  void describePurpose(string v) { _purpose = limitText(v, "Purpose"); changed; }
  void baseOn(LegalBasis b) { _legalBasis = b; changed; }
  void describeData(string categories, string subjects, string recipients) {
    _dataCategories = limitText(categories, "Data categories");
    _dataSubjects = limitText(subjects, "Data subject categories");
    _recipients = limitText(recipients, "Recipients");
    changed;
  }
  void retainFor(string v) { _retentionPeriod = limitText(v, "Retention period", 500); changed; }
  void protectWith(string v) { _toms = limitText(v, "Technical and organisational measures"); changed; }
  void classify(bool specialCategories, bool largeScale, bool systematicMonitoring, bool automatedDecisions) {
    _specialCategories = specialCategories;
    _largeScale = largeScale;
    _systematicMonitoring = systematicMonitoring;
    _automatedDecisions = automatedDecisions;
    changed;
  }
  void transfer(bool thirdCountry, string safeguard) {
    _thirdCountryTransfer = thirdCountry;
    _transferSafeguard = limitText(safeguard, "Transfer safeguard", 500);
    changed;
  }
  void recordDpia(bool completed) { _dpiaCompleted = completed; changed; }

  /// Puts the activity into effect; requires a complete Art. 30 record.
  void activate() { ensureComplete; _status = ActivityStatus.active; touch; }
  void retire() { _status = ActivityStatus.retired; touch; }
  void reopenDraft() { _status = ActivityStatus.draft; touch; }

  void changeStatus(ActivityStatus s) {
    final switch (s) {
      case ActivityStatus.draft: reopenDraft; break;
      case ActivityStatus.active: activate; break;
      case ActivityStatus.retired: retire; break;
    }
  }

  /// Active records must stay complete after every change.
  private void changed() {
    if (_status == ActivityStatus.active) ensureComplete;
    touch;
  }

  /// Rules for an active (productive) processing activity.
  void ensureComplete() const {
    string[] missing;
    if (_purpose.length == 0) missing ~= "purpose (Art. 30 (1) b)";
    if (_dataCategories.length == 0) missing ~= "data categories (Art. 30 (1) c)";
    if (_dataSubjects.length == 0) missing ~= "data subject categories (Art. 30 (1) c)";
    if (_retentionPeriod.length == 0) missing ~= "retention period (Art. 30 (1) f)";
    if (transferWithoutSafeguard) missing ~= "safeguard for the third-country transfer (Art. 44 ff.)";
    if (dpiaRequired && !_dpiaCompleted) missing ~= "completed DPIA (Art. 35)";
    if (missing.length) {
      import std.array : join;
      throw new ValidationException("Activity '" ~ _name ~ "' cannot be active, missing: " ~ missing.join("; "));
    }
  }
}

unittest {
  import std.exception : assertThrown;
  auto a = DProcessingActivity.create("a1", "p1", "Newsletter", "Marketing e-mails", LegalBasis.consent);
  assertThrown!ValidationException(a.activate);
  a.describeData("e-mail address", "customers", "mail provider");
  a.retainFor("until withdrawal");
  a.activate;
  assert(a.status == ActivityStatus.active && a.riskLevel == RiskLevel.low);
  assertThrown!ValidationException(a.transfer(true, ""));       // would break the active record
  a.transfer(true, "Standard contractual clauses");
  assert(a.riskLevel == RiskLevel.medium && !a.dpiaRequired);
}
