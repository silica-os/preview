// The Open Recent list.

import 'package:flutter_test/flutter_test.dart';
import 'package:preview/src/recent.dart';

void main() {
  setUp(RecentFiles.reset);

  test('the latest file is first, without duplicates, at most ten', () {
    for (var i = 0; i < 12; i++) {
      RecentFiles.add('/a/$i');
    }
    RecentFiles.add('/a/5');
    expect(RecentFiles.paths.first, '/a/5');
    expect(RecentFiles.paths.length, RecentFiles.limit);
    expect(RecentFiles.paths.where((p) => p == '/a/5').length, 1);
  });

  test('Clear Menu empties the list', () {
    RecentFiles.add('/a/1');
    RecentFiles.clear();
    expect(RecentFiles.paths, isEmpty);
  });
}
