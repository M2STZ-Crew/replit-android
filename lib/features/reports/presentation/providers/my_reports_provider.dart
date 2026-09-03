import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/report_api.dart';
import '../../domain/entities/report.dart';

/// The caller's own reports, newest first.
///
/// Kept as a FutureProvider so pull-to-refresh is `ref.invalidate` and the UI
/// gets loading and error states for free rather than hand-rolled flags. The
/// backend joins each report to its clustered area, so this carries live
/// lifecycle status — the list is a progress view, not just a receipt.
final myReportsProvider = FutureProvider<List<MyReport>>((ref) async {
  final result = await ref.watch(reportApiProvider).myReports();
  return result.when(
    success: (reports) => reports,
    // Throwing surfaces it as AsyncError with the server's own message, which
    // is friendlier than a bare status code.
    failure: (error) => throw error,
  );
});
