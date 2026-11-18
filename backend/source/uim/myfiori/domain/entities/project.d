/// GDPR (privacy) project: the organisational scope of a data protection programme.
module uim.myfiori.domain.entities.project;

@safe:

import std.datetime.systime : SysTime;
import uim.myfiori.domain.entities.base;
import uim.myfiori.domain.enumerations;
import uim.myfiori.domain.exceptions;
import uim.myfiori.domain.types;

class DProject : DEntity {
  private string _name;
  private string _description;
  private string _controller;     // controller (Art. 4 (7)): legal entity responsible for the processing
  private string _dpoName;        // data protection officer (Art. 37)
  private string _dpoEmail;
  private ProjectStatus _status;

  /// Restores a persisted project.
  this(EntityId id, string name, string description, string controller, string dpoName, string dpoEmail,
      ProjectStatus status, SysTime createdAt, SysTime modifiedAt) {
    super(id, createdAt, modifiedAt);
    _name = requireText(name, "Project name");
    _description = limitText(description, "Description");
    _controller = limitText(controller, "Controller", 255);
    _dpoName = limitText(dpoName, "DPO name", 255);
    _dpoEmail = validateEmail(dpoEmail, "DPO e-mail", true);
    _status = status;
  }

  /// Creates a new project in status "planned".
  static DProject create(EntityId id, string name, string description, string controller, string dpoName, string dpoEmail) {
    auto t = now;
    return new DProject(id, name, description, controller, dpoName, dpoEmail, ProjectStatus.planned, t, t);
  }

  string name() const pure nothrow { return _name; }
  string description() const pure nothrow { return _description; }
  string controller() const pure nothrow { return _controller; }
  string dpoName() const pure nothrow { return _dpoName; }
  string dpoEmail() const pure nothrow { return _dpoEmail; }
  ProjectStatus status() const pure nothrow { return _status; }

  void rename(string v) { ensureWritable; _name = requireText(v, "Project name"); touch; }
  void describe(string v) { ensureWritable; _description = limitText(v, "Description"); touch; }
  void assignController(string v) { ensureWritable; _controller = limitText(v, "Controller", 255); touch; }
  void appointDpo(string name, string email) {
    ensureWritable;
    _dpoName = limitText(name, "DPO name", 255);
    _dpoEmail = validateEmail(email, "DPO e-mail", true);
    touch;
  }

  /// Any status change is allowed; archiving freezes the project and all its registers.
  void changeStatus(ProjectStatus s) { _status = s; touch; }

  bool archived() const pure nothrow { return _status == ProjectStatus.archived; }

  /// Throws ConflictException if the project (or one of its registers) must not be changed.
  void ensureWritable() const {
    if (archived) throw new ConflictException("Project '" ~ _name ~ "' is archived and read-only");
  }
}

unittest {
  import std.exception : assertThrown;
  auto p = DProject.create("p1", "GDPR 2026", "", "ACME GmbH", "Erika", "dpo@acme.example");
  assert(p.status == ProjectStatus.planned);
  assertThrown!ValidationException(p.rename(" "));
  p.changeStatus(ProjectStatus.archived);
  assertThrown!ConflictException(p.rename("x"));
}
