/**
 * Document storage persisted as one JSON file. Every change is written
 * atomically (temp file + rename) so a crash never leaves a truncated file.
 */
module uim.myfiori.persistence.storages.jsonfile;

@safe:

import std.file : exists, mkdirRecurse, readText, rename, write;
import std.path : dirName;
import vibe.data.json : Json, parseJsonString;
import uim.myfiori.persistence.storages.memory;

class DJsonFileDocumentStorage : DMemoryDocumentStorage {
  private string _path;

  this(string path) {
    _path = path;
    load();
  }

  string path() const pure nothrow @nogc { return _path; }

  override void flush() {
    if (inTransaction) return;   // committed together in commit()
    auto root = Json.emptyObject;
    foreach (collection, docs; _data) {
      auto c = Json.emptyObject;
      foreach (id, doc; docs) c[id] = doc;
      root[collection] = c;
    }
    auto dir = _path.dirName;
    if (dir.length && !dir.exists) mkdirRecurse(dir);
    auto tmp = _path ~ ".tmp";
    write(tmp, root.toPrettyString);
    rename(tmp, _path);
  }

  override string describe() { return "json:" ~ _path; }

  protected override void persist() { flush(); }

  private void load() @trusted {
    if (!_path.exists) return;
    auto text = readText(_path);
    if (text.length == 0) return;
    auto root = parseJsonString(text, _path);
    foreach (string collection, docs; root)
      foreach (string id, doc; docs)
        _data[collection][id] = doc;
  }
}
