import 'package:flutter/material.dart';

import '../models/field_ops.dart';
import '../theme.dart';
import '../widgets/coordinator_kit.dart';
import '../widgets/design.dart';
import '../widgets/field_ops.dart';
import '../widgets/map_pitch.dart';

/// DEVELOPMENT PREVIEW ONLY — the pass 6 field-operations parts that are
/// UI READY: drawn and working on screen, with no server behind them yet
/// (PRD v13 §17.3 lists the missing endpoints; see
/// docs/FRONTEND_INTEGRATION_HANDOFF.md). Every name, place and number here
/// is fictional, and nothing is sent anywhere.
///
///     flutter run -t lib/dev/preview_main.dart
///
/// No production route reaches these parts: the app's own entry point is
/// lib/main.dart.
void main() => runApp(const FieldOpsPreview());

class FieldOpsPreview extends StatelessWidget {
  const FieldOpsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepLiT field operations (preview)',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _Gallery(),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery();

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  FireClassification? _fire;
  int _water = 60;
  SafetyAnswer? _answer;
  int _pitch = kLaunchPitch;
  String? _last;

  void _said(String what) => setState(() => _last = what);

  Future<void> _pickFireType() async {
    final picked = await showFrameSheet<FireClassification>(
      context,
      builder: (_) => const FireTypeSheet(
        areaLabel: 'Example Area 1.2',
        arrivedAt: '9:49 PM',
      ),
    );
    if (picked != null) setState(() => _fire = picked);
  }

  Future<void> _request(FieldRequestType type) async {
    await showFrameSheet<FieldRequest>(
      context,
      builder: (_) => RequestSheet(
        type: type,
        eyebrow: 'Example Area 1.2',
        recipient: 'Example Fire Volunteers Admin',
        onSend: (request) async => _said('Preview: ${type.label} not sent'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          children: [
            const TabHeader(
              eyebrow: 'Development preview · fictional data',
              title: 'Field operations',
              subtitle:
                  'UI READY: these parts wait on server support and are not '
                  'in the app yet.',
            ),
            if (_last != null) ...[InlineAlert(body: _last!), gap],
            const SectionHeader('Driving map (PRD v14 §4.9.1)'),
            const SizedBox(height: 12),
            Row(
              children: [
                MapPitchButton(
                  pitch: _pitch,
                  onChanged: (p) => setState(() => _pitch = p),
                ),
                const SizedBox(width: 12),
                const MapPitchButton(pitch: 0),
                const SizedBox(width: 12),
                const Flexible(child: Map3dUnavailableBanner()),
              ],
            ),
            gap,
            const SectionHeader('On scene (C18, C20)'),
            const SizedBox(height: 12),
            AppButton.secondary(
              _fire == null
                  ? 'Pick the fire type'
                  : 'Fire type: ${_fire!.type.label}'
                        '${_fire!.subtype == null ? '' : ' · ${_fire!.subtype}'}',
              onPressed: _pickFireType,
            ),
            const SizedBox(height: 12),
            FieldActions(fireType: _fire, onRequest: _request),
            gap,
            const SectionHeader('Water level (C19c)'),
            const SizedBox(height: 12),
            WaterLevelSlider(
              pct: _water,
              onChanged: (v) => setState(() => _water = v),
            ),
            const SizedBox(height: 12),
            WaterLevelBar(pct: _water),
            gap,
            const SectionHeader('A resident nearby (Citizen 11)'),
            const SizedBox(height: 12),
            SafetyPromptCard(
              eyebrow: 'Example Barangay alert',
              title: 'Do you see it too?',
              place: 'Example Street, 120 m from you',
              onReport: () => _said('Preview: Report not sent'),
              onIgnore: () => _said('Preview: Ignore not sent'),
              answer: _answer,
              onSafety: (a) => setState(() => _answer = a),
            ),
            gap,
            const SafetyRollCallStrip(
              title: 'Safety roll call · Example Area 1.2',
              rollCall: SafetyRollCall(safe: 12, needHelp: 1, notInArea: 4),
              updated: 'Updated just now',
            ),
            gap,
            const SectionHeader('For the responding Coordinator (C11c, C11d)'),
            const SizedBox(height: 12),
            HelpAlertCard(
              raisedAt: '9:52 PM',
              where: 'Example Street corner Sample Avenue',
              contact: '0900 000 0000',
              onCall: () => _said('Preview: no call placed'),
              onShowOnMap: () => _said('Preview: no map opened'),
            ),
            gap,
            const FireOutSignalCard(votes: 3, window: 'in the last 10 minutes'),
            gap,
            const SectionHeader('The report (C14–C14d)'),
            const SizedBox(height: 12),
            for (final state in CiarState.values) ...[
              CiarStatusCard(
                state: state,
                reference: 'CIAR-EXAMPLE-0001',
                lockedAt: state == CiarState.ready ? '10:31 PM' : null,
                onView: state == CiarState.ready
                    ? () => _said('Preview: no CIAR to open')
                    : null,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
