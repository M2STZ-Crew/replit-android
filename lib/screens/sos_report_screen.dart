import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/responder_unit.dart';
import '../theme.dart';
import '../widgets/design.dart';
import '../widgets/incident_map.dart';
import 'report_status_screen.dart';

/// "What kind of help?" — step 3 of the SOS flow, after the photo is captured.
///
/// The v2 design asks this as "What's happening?" with one answer (Fire /
/// Medical / Crime), each mapping to the agencies that respond to it. This
/// screen keeps the app's existing multi-select over the four agencies, because
/// /reports/submit takes a list and a resident who needs both an ambulance and
/// a fire truck should be able to say so. What it takes from the design is the
/// card: an icon well, a plain-language line, and a round check.
class SosReportScreen extends StatefulWidget {
  const SosReportScreen({
    super.key,
    required this.photoBytes,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.address,
  });

  final List<int> photoBytes;
  final double lat;
  final double lng;
  final double? accuracyM;
  final String? address;

  @override
  State<SosReportScreen> createState() => _SosReportScreenState();
}

class _SosReportScreenState extends State<SosReportScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _notes = TextEditingController();
  final Map<String, bool> _selected = {
    'fire_volunteer': true,
    'police': false,
    'medical': false,
    'barangay': false,
  };

  bool _submitting = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.live),
    );
  }

  Future<void> _requestHelp() async {
    final agencies = _selected.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (agencies.isEmpty) {
      _toast('Choose at least one kind of help.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final data = await _api.submitReport(
        lat: widget.lat,
        lng: widget.lng,
        accuracyM: widget.accuracyM,
        agencies: agencies,
        notes: _notes.text.trim(),
        photoBytes: widget.photoBytes,
      );
      if (!mounted) return;
      await _showSuccess(data, agencies);
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not submit the report. Check your connection.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccess(
    Map<String, dynamic> data,
    List<String> agencies,
  ) async {
    final createdRaw = data['created_at'] as String?;
    DateTime when;
    try {
      when = createdRaw != null
          ? DateTime.parse(createdRaw).toLocal()
          : DateTime.now();
    } catch (_) {
      when = DateTime.now();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReportStatusScreen(
          designation: (data['area_designation'] as String?) ?? '—',
          message: data['message'] as String?,
          areaId: data['area_id'] as String?,
          lat: widget.lat,
          lng: widget.lng,
          submittedAt: when,
          selectedAgencies: agencies,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chosen = _selected.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                children: [
                  Row(
                    children: [
                      BackWell(
                        onTap: _submitting
                            ? () {}
                            : () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Eyebrow('Step 3 of 3', color: AppColors.accent),
                            SizedBox(height: 6),
                            Text('PHOTO CAPTURED', style: AppText.screenTitle),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const Text("WHAT'S HAPPENING?", style: AppText.display),
                  const SizedBox(height: 8),
                  const Text(
                    'Pick everyone you need. We already know where you are.',
                    style: AppText.body,
                  ),
                  const SizedBox(height: 22),
                  _evidenceCard(),
                  const SizedBox(height: 26),
                  const Eyebrow('Who should respond?', color: AppColors.accent),
                  const SizedBox(height: 12),
                  for (final unit in kResponderUnits) ...[
                    _unitCard(unit),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 10),
                  const Eyebrow('Optional note'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notes,
                    maxLines: 4,
                    minLines: 3,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.onBackground,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Anything responders should know…',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: AppButton.secondary(
                      'Cancel',
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      chosen == 0 ? 'Choose who to call' : 'Send report',
                      busy: _submitting,
                      onPressed: _submitting || chosen == 0
                          ? null
                          : _requestHelp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The map and the photo together — proof that both halves of the evidence
  /// are attached before anything is sent.
  Widget _evidenceCard() {
    final label =
        widget.address ??
        '${widget.lat.toStringAsFixed(4)}, ${widget.lng.toStringAsFixed(4)}';

    return Container(
      height: 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IncidentMap(lat: widget.lat, lng: widget.lng),
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: AppColors.lineLight),
              ),
              child: Image.memory(
                Uint8List.fromList(widget.photoBytes),
                width: 76,
                height: 76,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(left: 12, bottom: 12, right: 12, child: _gpsChip(label)),
        ],
      ),
    );
  }

  Widget _gpsChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.canvas.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveDot(size: 6),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.onBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitCard(ResponderUnit unit) {
    final selected = _selected[unit.key] ?? false;
    final tint = AppColors.forAgency(unit.key);

    return Panel(
      onTap: () => setState(() => _selected[unit.key] = !selected),
      color: selected ? tint.withValues(alpha: 0.1) : AppColors.glassDim,
      border: selected ? tint : AppColors.line,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          IconWell(tint: tint, icon: unit.icon, size: 48, glyph: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  unit.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle.copyWith(
                    fontSize: 16,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  unit.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.meta,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? tint : Colors.transparent,
              border: Border.all(
                color: selected ? tint : AppColors.lineStrong,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: AppColors.background,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
