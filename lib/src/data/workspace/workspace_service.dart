import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

/// A workspace failure with a stable, safe code for callers and logs.
class WorkspaceException implements Exception {
  const WorkspaceException(this.code, this.message, [this.cause]);

  /// Machine-readable code: `workspace_unavailable` when the workspace could
  /// not be opened, `workspace_outside_root` when a delete target escapes its
  /// root, `workspace_delete_failed` when the filesystem refused the delete.
  final String code;
  final String message;

  /// The underlying platform error, kept for logging. Never user content.
  final Object? cause;

  @override
  String toString() => 'WorkspaceException($code): $message';
}

/// Owns the local storage root and the lifetime of the workspace database.
///
/// Everything the app persists lives under one folder inside the application
/// support directory, so no data is written to shared or synced locations and
/// nothing is uploaded. The root is injectable, so tests never touch the real
/// application support folder.
class WorkspaceService {
  /// Creates a service. Pass [rootDirectory] to use a specific root instead of
  /// the platform application support directory.
  WorkspaceService({Directory? rootDirectory}) : _rootOverride = rootDirectory;

  /// Folder created inside the root.
  static const String workspaceDirectoryName = 'workspace';

  /// Database file name inside the workspace folder.
  static const String databaseFileName = 'personal_data_agent.sqlite';

  final Directory? _rootOverride;

  Directory? _workspaceDirectory;
  AppDatabase? _database;
  String? _databasePath;

  /// The in-flight [open], shared by overlapping callers so two callers cannot
  /// create two database handles for the same workspace.
  Future<void>? _opening;

  /// Incremented by every [close]. An open that finishes after a close has
  /// begun sees a different generation and closes its own handle instead of
  /// publishing a database the caller believes is shut.
  int _generation = 0;

  /// True once [open] has completed and [close] has not been called.
  bool get isOpen => _database != null;

  /// Absolute path of the open database file, or null while closed.
  String? get currentDatabasePath => _databasePath;

  /// The workspace folder, or null while closed.
  Directory? get workspaceDirectory => _workspaceDirectory;

  /// The open database. Throws [StateError] when the workspace is closed, so a
  /// caller cannot silently use a database that was never opened.
  AppDatabase get database {
    final database = _database;
    if (database == null) {
      throw StateError('The workspace is not open; call open() first.');
    }
    return database;
  }

  /// Bytes currently stored in the workspace folder, or 0 when it is closed,
  /// absent or unreadable.
  ///
  /// The walk uses `lstat` semantics and never follows a symbolic link: a link
  /// is skipped, not measured, so it cannot inflate the number or expose a
  /// target outside the workspace.
  Future<int> workspaceSizeBytes() async {
    final workspace = _workspaceDirectory;
    if (workspace == null || !await workspace.exists()) return 0;
    try {
      return await _directoryBytes(workspace);
    } on FileSystemException {
      return 0;
    } on OSError {
      return 0;
    }
  }

  Future<int> _directoryBytes(Directory directory) async {
    var total = 0;
    await for (final entry in directory.list(followLinks: false)) {
      final type = await FileSystemEntity.type(entry.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        total += await _directoryBytes(Directory(entry.path));
      } else if (type == FileSystemEntityType.file) {
        total += await File(entry.path).length();
      }
      // Links and anything else are skipped, never followed.
    }
    return total;
  }

  /// Whether the workspace folder is already present in the root.
  Future<bool> workspaceExists() async {
    final workspace = await _resolveWorkspaceDirectory();
    return workspace.exists();
  }

  /// Creates the workspace folder if needed and opens its database.
  ///
  /// Calling this while open is a no-op, and overlapping calls share one
  /// open. A [close] that starts while an open is in flight wins: the open
  /// discards its new handle instead of reviving a closed workspace. Any
  /// platform failure (unwritable or unusable root, corrupt database) is
  /// reported as a [WorkspaceException].
  Future<void> open() {
    if (_database != null) return Future<void>.value();
    final pending = _opening;
    if (pending != null) return pending;

    final future = _open();
    _opening = future;
    return future.whenComplete(() {
      if (identical(_opening, future)) _opening = null;
    });
  }

  Future<void> _open() async {
    final generation = _generation;
    if (kIsWeb) {
      // A browser has no application-support folder and no sqlite file: drift
      // keeps the database in IndexedDB/OPFS under a fixed name, so there is
      // nothing to create and no path to report.
      final database = AppDatabase.atPath(databaseFileName);
      try {
        await database.customSelect('SELECT 1').get();
      } catch (error) {
        await database.close();
        throw WorkspaceException(
          'workspace_unavailable',
          'The workspace database could not be opened.',
          error,
        );
      }
      if (generation != _generation) {
        await database.close();
        return;
      }
      _database = database;
      return;
    }

    final workspace = await _resolveWorkspaceDirectory();
    try {
      await workspace.create(recursive: true);
    } on FileSystemException catch (error) {
      throw WorkspaceException(
        'workspace_unavailable',
        'The workspace folder could not be created.',
        error,
      );
    } on OSError catch (error) {
      throw WorkspaceException(
        'workspace_unavailable',
        'The workspace folder could not be created.',
        error,
      );
    }

    final databasePath = p.join(workspace.path, databaseFileName);
    final database = AppDatabase.atPath(
      databasePath,
      // sqlite3's intermediate files stay inside the workspace, never in a
      // shared temporary directory.
      tempDirectoryPath: workspace.path,
    );
    try {
      // Opening is lazy, so touch the database to surface a real failure here
      // instead of on the first query seen by the user.
      await database.customSelect('SELECT 1').get();
    } catch (error) {
      await database.close();
      throw WorkspaceException(
        'workspace_unavailable',
        'The workspace database could not be opened.',
        error,
      );
    }

    if (generation != _generation) {
      // close() ran while the database was opening. Do not publish a handle
      // whose workspace the caller already closed.
      await database.close();
      return;
    }

    _workspaceDirectory = workspace;
    _databasePath = databasePath;
    _database = database;
  }

  /// Deletes the workspace folder and everything the app stored in it.
  ///
  /// The database is closed first, then its SQLite side files (journal, write
  /// ahead log, shared memory) and the rest of the folder are removed. The
  /// tree walk uses `lstat` semantics and never traverses a symbolic link: a
  /// link is unlinked, so its target is left untouched.
  ///
  /// The workspace folder must resolve inside the root and must not itself be
  /// a link; otherwise nothing is deleted and a [WorkspaceException] with code
  /// `workspace_outside_root` is thrown. Deleting a workspace that is already
  /// gone (or was never created) succeeds quietly.
  Future<void> deleteWorkspace() async {
    await close();

    final root = await _rootDirectory();
    final workspacePath = p.join(root.path, workspaceDirectoryName);
    final workspaceType = await FileSystemEntity.type(
      workspacePath,
      followLinks: false,
    );
    if (workspaceType == FileSystemEntityType.notFound) return;

    // Fully resolved comparison: a workspace link that points away from the
    // root resolves somewhere else and is refused, while a root that is itself
    // a link is fine because both sides resolve the same way.
    final resolvedRoot = await _resolvedPath(root.path);
    final resolvedWorkspace = workspaceType == FileSystemEntityType.link
        ? null
        : await _resolvedPath(workspacePath);
    if (resolvedWorkspace != p.join(resolvedRoot, workspaceDirectoryName)) {
      throw WorkspaceException(
        'workspace_outside_root',
        'The workspace folder resolves outside its root; nothing was deleted.',
      );
    }

    try {
      if (workspaceType != FileSystemEntityType.directory) {
        // A stray file sitting where the folder belongs: remove that entry.
        await File(workspacePath).delete();
        return;
      }
      await _deleteSqliteSideFiles(workspacePath);
      await _deleteTree(Directory(workspacePath));
    } on FileSystemException catch (error) {
      throw WorkspaceException(
        'workspace_delete_failed',
        'The workspace folder could not be deleted completely.',
        error,
      );
    } on OSError catch (error) {
      throw WorkspaceException(
        'workspace_delete_failed',
        'The workspace folder could not be deleted completely.',
        error,
      );
    }
  }

  /// Removes the database file and the SQLite side files next to it.
  Future<void> _deleteSqliteSideFiles(String workspacePath) async {
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final file = File(p.join(workspacePath, '$databaseFileName$suffix'));
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // The tree walk below removes whatever is left.
      }
    }
  }

  /// Deletes [directory] bottom up without following symbolic links.
  Future<void> _deleteTree(Directory directory) async {
    await for (final entry in directory.list(followLinks: false)) {
      final type = await FileSystemEntity.type(entry.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await _deleteTree(Directory(entry.path));
        continue;
      }
      // Anything else, including a link: remove this entry only. A link's
      // target is never visited.
      await entry.delete();
    }
    await directory.delete();
  }

  Future<String> _resolvedPath(String path) =>
      Directory(path).resolveSymbolicLinks();

  /// Closes the workspace database. Safe to call when already closed.
  Future<void> close() async {
    // Invalidate any open that is still in flight before awaiting the close.
    _generation++;
    final database = _database;
    _database = null;
    _databasePath = null;
    _workspaceDirectory = null;
    if (database != null) await database.close();
  }

  Future<Directory> _rootDirectory() async =>
      _rootOverride ?? await _applicationSupportDirectory();

  Future<Directory> _resolveWorkspaceDirectory() async {
    final root = await _rootDirectory();
    // An absolute root keeps `currentDatabasePath` absolute even when the
    // caller passes a relative directory, so sqlite never resolves the file
    // against whatever working directory the process happens to have.
    return Directory(
      p.join(p.absolute(root.path), workspaceDirectoryName),
    );
  }

  Future<Directory> _applicationSupportDirectory() async {
    try {
      return await getApplicationSupportDirectory();
    } on Object catch (error) {
      throw WorkspaceException(
        'workspace_unavailable',
        'The application support folder could not be resolved.',
        error,
      );
    }
  }
}
