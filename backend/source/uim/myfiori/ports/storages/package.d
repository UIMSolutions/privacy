/// Driven ports for low-level document stores.
module uim.myfiori.ports.storages;

@safe:

import vibe.data.json : Json;

/// Complete content of a store: collection -> id -> document.
alias StorageSnapshot = Json[string][string];

/// Schemaless document store organised in collections of JSON documents keyed by id.
interface IDocumentStorage {
  Json[] all(string collection);
  Json get(string collection, string id);   // Json.undefined if missing
  void put(string collection, string id, Json document);
  bool remove(string collection, string id);
  /// Persists pending changes (no-op for volatile stores).
  void flush();
  /// Human readable description (e.g. "json:/var/data/gdpr.json").
  string describe();

  /// Copy of the complete content (for backups).
  StorageSnapshot snapshot();
  /// Replaces the complete content atomically (for restores).
  void replaceAll(StorageSnapshot data);
}

/**
 * Unit of work on the document store. Changes made between begin() and commit()
 * are persisted together; rollback() restores the state of begin().
 * Transactions are not nested.
 */
interface ITransactionManager {
  void begin();
  void commit();
  void rollback();
  bool inTransaction();
}
