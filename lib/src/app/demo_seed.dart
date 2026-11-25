// Demo seeding for browser QA.
//
// A browser cannot hand the app a file from disk, so browser-driven tests can
// never exercise the archive screens. Opening `/?demo=fx` imports the bundled
// synthetic export once, so every screen has real rows to filter and assert on.
//
// ponytail: QA-only path, whole ZIP held in memory (~200 KB). Stream it if a
// real archive ever ships as the demo.
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_data_agent/src/features/import/import_controller.dart';
import 'package:personal_data_agent/src/features/overview/overview_controller.dart';

const demoAssetPath = 'assets/demo/facebook-export.zip';

/// Imports the bundled demo export when the URL asks for it (`?demo=fx`).
///
/// Returns true when a seed actually ran. Never throws: a failed seed must not
/// become an unhandled async error in a QA run that is looking elsewhere.
Future<bool> seedDemoArchiveIfRequested(ProviderContainer container) async {
  if (!kIsWeb) return false;
  if (Uri.base.queryParameters['demo'] != 'fx') return false;
  try {
    // Refuse to touch a workspace that already holds events. Web storage keeps
    // the database between visits, so seeding blindly would stack a second copy
    // on every reload — and, worse, mix synthetic rows into a real archive.
    final stats = await container.read(overviewStatsProvider.future);
    if (stats.totalEvents > 0) {
      debugPrint('demo seed: skipped, archive holds ${stats.totalEvents} events');
      return false;
    }
    final data = await rootBundle.load(demoAssetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    debugPrint('demo seed: ${bytes.length} bytes from $demoAssetPath');
    await container.read(importRunProvider.notifier).runBytes(
      bytes,
      label: 'demo-export.zip',
    );
    return true;
  } on Object catch (error) {
    debugPrint('demo seed failed: $error');
    return false;
  }
}
