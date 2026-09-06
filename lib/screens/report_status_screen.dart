import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/design.dart';
import '../widgets/incident_map.dart';
import 'live_update_screen.dart';

/// "Report sent" — the confirmation the v2 design shows after the SOS flow.
///
/// The design's version says "Getting you help" over a progress ring. By the
/// time this screen is reached the upload is finished and the server has
/// answered with an area designation, so the copy says what is actually true:
/// the report landed, a coordinator reviews it next, and neighbours nearby
/// have been alerted.
class ReportStatusScreen extends StatelessWidget {
  const ReportStatusScreen({
    super.key,
    required this.designation,
    required this.lat,
    required this.lng,
    required this.submittedAt,
    this.message,
    this.areaId,
    this.emergencyType = 'Fire Incident',
    this.selectedAgencies = const [],
  });

  final String designation;
  final double lat;
  final double lng;
  final DateTime submittedAt;
  final String? message;
  final String? areaId;
  final String emergencyType;
  final List<String> selectedAgencies;

  String _fmtTime(DateTime d) {
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    var h = d.hour % 12;
    if (h == 0) h = 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final mapHeight = MediaQuery.sizeOf(context).height * 0.42;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SizedBox(
            height: mapHeight,
            width: double.infinity,
            child: IncidentMap(lat: lat, lng: lng),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: mapHeight - 24),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sheet),
                  ),
                  border: Border(
                    top: BorderSide(color: Color(0x0DFFFFFF)),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  children: [
                    const Center(child: SheetHandle()),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.ok.withValues(alpha: 0.14),
                            border: Border.all(
                              color: AppColors.ok.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 22,
                            color: AppColors.ok,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Eyebrow('Sent', color: AppColors.ok),
                              SizedBox(height: 6),
                              Text('REPORT SENT', style: AppText.title),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      message ??
                          'Your report joined $designation. A Fire Volunteer '
                              'coordinator reviews it next, and neighbours '
                              'nearby have been alerted.',
                      style: AppText.body,
                    ),
                    const SizedBox(height: 22),

                    _factRow(
                      'Incident',
                      designation,
                      art: Art.incident,
                      tint: AppColors.accent,
                      highlight: true,
                    ),
                    const SizedBox(height: 10),
                    _factRow(
                      'Reported',
                      _fmtTime(submittedAt),
                      icon: Icons.schedule_rounded,
                      tint: AppColors.label,
                    ),
                    const SizedBox(height: 10),
                    _factRow(
                      'Location',
                      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                      icon: Icons.place_outlined,
                      tint: AppColors.label,
                    ),

                    if (areaId != null) ...[
                      const SizedBox(height: 24),
                      AppButton(
                        'Track response live',
                        icon: Icons.podcasts_rounded,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LiveUpdateScreen(
                              areaId: areaId!,
                              lat: lat,
                              lng: lng,
                              alreadySelected: selectedAgencies,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Panel(
                      radius: AppRadius.control,
                      color: AppColors.glassDim,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your photo is held in private storage. Only '
                              'responders can open it.',
                              style: AppText.meta.copyWith(height: 16 / 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Align(
                alignment: Alignment.topLeft,
                child: BackWell(onTap: () => Navigator.of(context).pop()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _factRow(
    String label,
    String value, {
    String? art,
    IconData? icon,
    required Color tint,
    bool highlight = false,
  }) {
    return Panel(
      radius: AppRadius.control,
      color: highlight ? tint.withValues(alpha: 0.09) : AppColors.glassDim,
      border: highlight ? tint.withValues(alpha: 0.4) : AppColors.line,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          IconWell(tint: tint, asset: art, icon: icon, size: 36, glyph: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Eyebrow(label, color: AppColors.muted),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
