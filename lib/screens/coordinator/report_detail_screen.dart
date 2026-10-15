import 'package:flutter/material.dart';

import '../../location/place_names.dart';
import '../../models/area_view.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/coordinator_kit.dart';
import '../../widgets/design.dart';
import '../../widgets/photo_viewer.dart';

/// One report in an Area, as staff see it: the photo (staff-only), who sent
/// it and how verified they are, when, what they asked for, what they wrote,
/// and where the phone was.
class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({
    super.key,
    required this.report,
    required this.number,
  });

  /// An IncidentReportDetail row.
  final Map<String, dynamic> report;

  /// Its place in the Area's list, from 1.
  final int number;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final pal = context.pal;
    final at = parseTime(r['created_at']);
    final pct = (r['user_verified_percent'] as num?)?.toInt() ?? 0;
    final name = (r['reporter_name'] as String?)?.trim();
    final notes = (r['notes'] as String?)?.trim();
    final photo = r['photo_url'] as String?;
    final lat = (r['device_lat'] as num?)?.toDouble();
    final lng = (r['device_lng'] as num?)?.toDouble();
    final asked = askedFor(
      ((r['selected_agencies'] as List?) ?? const []).whereType<String>(),
    );
    return Scaffold(
      backgroundColor: pal.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailHeader(
              eyebrow: 'Report $number',
              title: name == null || name.isEmpty ? 'Resident' : name,
              subtitle:
                  '$pct% verified'
                  '${at == null ? '' : ' · ${whenText(at)}'}',
            ),
            Expanded(
              child: ScrollFade(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    kScrollFadeEndPadding,
                  ),
                  children: [
                    if (photo != null) ...[
                      GestureDetector(
                        onTap: () =>
                            openPhoto(context, photo, label: 'Report photo'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.network(
                              photo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: pal.surface,
                                alignment: Alignment.center,
                                child: Icon(
                                  AppIcons.brokenImage,
                                  color: pal.label,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SectionHeader('What they sent'),
                    const SizedBox(height: 12),
                    ListRow(
                      leading: const IconPlate(AppIcons.description),
                      title: notes == null || notes.isEmpty
                          ? 'No description'
                          : notes,
                      subtitle: asked.isEmpty ? null : 'Asked for $asked',
                    ),
                    const SizedBox(height: 8),
                    if (lat != null && lng != null)
                      // The street first, from the phone's geocoder; the
                      // degrees stay, since they are what was sent.
                      FutureBuilder<PlaceName>(
                        future: PlaceNames.of(lat, lng),
                        builder: (context, snap) => ListRow(
                          leading: const IconPlate(AppIcons.locationOn),
                          title: 'Where the phone was',
                          subtitle: [
                            ?snap.data?.line,
                            degrees(lat, lng),
                          ].join(' · '),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (r['gps_discrepancy_flag'] == true)
                      const InlineAlert(
                        tone: AlertTone.warning,
                        title: 'The photo and the phone disagree',
                        body:
                            'The location in the photo is far from where the '
                            'phone said it was. Weigh this report with care.',
                      )
                    else if (r['has_exif'] != true && photo != null)
                      const InlineAlert(
                        body:
                            'The photo carries no location of its own, so only '
                            'the phone says where it was taken.',
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
