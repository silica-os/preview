// Undo and redo, and whether the document has changes not written to its file ("Edited" under
// the title). Every change to a document is an [Edit]: what it does and how to take it back.

import 'package:flutter/foundation.dart';

/// One change: [redo] applies it (it has been applied once when recorded), [undo] takes it
/// back.
class Edit {
  Edit({required this.undo, required this.redo});
  final VoidCallback undo;
  final VoidCallback redo;
  late final int _id;
}

class EditHistory {
  final List<Edit> _done = [];
  final List<Edit> _undone = [];
  int _next = 1;

  /// The state written to the file: the id of the last edit applied then (0: none).
  int _saved = 0;

  int get _state => _done.isEmpty ? 0 : _done.last._id;

  /// Changes not written to the file.
  bool get edited => _state != _saved;

  bool get canUndo => _done.isNotEmpty;
  bool get canRedo => _undone.isNotEmpty;

  /// Records `edit`, already applied.
  void record(Edit edit) {
    edit._id = _next++;
    _done.add(edit);
    _undone.clear();
  }

  void undo() {
    if (_done.isEmpty) return;
    final edit = _done.removeLast();
    edit.undo();
    _undone.add(edit);
  }

  void redo() {
    if (_undone.isEmpty) return;
    final edit = _undone.removeLast();
    edit.redo();
    _done.add(edit);
  }

  /// The document was written as it is now.
  void saved() => _saved = _state;

  /// Forgets everything (a new document, a revert).
  void clear() {
    _done.clear();
    _undone.clear();
    _saved = 0;
  }
}
