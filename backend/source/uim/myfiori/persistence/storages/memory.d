/// Volatile in-memory document storage (tests, demos) with snapshot transactions.
module uim.myfiori.persistence.storages.memory;

@safe:

import vibe.data.json : Json;
import uim.myfiori.domain.exceptions : ConflictException;
import uim.myfiori.ports.storages;

class DMemoryDocumentStorage : IDocumentStorage, ITransactionManager {
  protected StorageSnapshot _data;   // collection -> id -> document
  private StorageSnapshot _txBackup;
  private bool _inTx;

  Json[] all(string collection) {
    if (auto c = collection in _data) return c.values;
    return null;
  }

  Json get(string collection, string id) {
    if (auto c = collection in _data)
      if (auto d = id in *c) return *d;
    return Json.undefined;
  }

  void put(string collection, string id, Json document) {
    _data[collection][id] = document;
    changed();
  }

  bool remove(string collection, string id) {
    if (auto c = collection in _data) {
      if (id in *c) {
        (*c).remove(id);
        changed();
        return true;
      }
    }
    return false;
  }

  void flush() {}

  string describe() { return "memory"; }

  /// Documents are never mutated in place (put replaces them), so copying the maps is sufficient.
  StorageSnapshot snapshot() { return copyOf(_data); }

  void replaceAll(StorageSnapshot data) {
    if (_inTx) throw new ConflictException("Cannot replace the data set inside a transaction");
    _data = copyOf(data);
    changed();
  }

  // ------------------------------------------------------------ ITransactionManager

  void begin() {
    if (_inTx) throw new ConflictException("Another import/restore is in progress");
    _txBackup = copyOf(_data);
    _inTx = true;
  }

  void commit() {
    if (!_inTx) return;
    _inTx = false;
    _txBackup = null;
    changed();
  }

  void rollback() {
    if (!_inTx) return;
    _data = _txBackup;
    _txBackup = null;
    _inTx = false;
  }

  bool inTransaction() { return _inTx; }

  /// Hook for persistent subclasses; suppressed while a transaction is open.
  protected final void changed() { if (!_inTx) persist(); }
  protected void persist() {}

  protected static StorageSnapshot copyOf(StorageSnapshot src) {
    StorageSnapshot dst;
    foreach (collection, docs; src) {
      Json[string] c;
      foreach (id, doc; docs) c[id] = doc;
      dst[collection] = c;
    }
    return dst;
  }
}

unittest {
  auto s = new DMemoryDocumentStorage;
  s.put("a", "1", Json("x"));
  s.begin();
  s.put("a", "2", Json("y"));
  s.remove("a", "1");
  s.rollback();
  assert(s.get("a", "1") == Json("x") && s.get("a", "2").type == Json.Type.undefined);
  s.begin();
  s.put("a", "3", Json("z"));
  s.commit();
  assert(s.all("a").length == 2);
  auto snap = s.snapshot;
  s.put("a", "4", Json("w"));
  assert(snap["a"].length == 2);
  s.replaceAll(snap);
  assert(s.all("a").length == 2);
}
