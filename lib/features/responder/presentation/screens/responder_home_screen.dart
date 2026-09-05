import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/design.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../domain/entities/responder_incident.dart';
import '../providers/responder_provider.dart';
import '../providers/tracking_provider.dart';

/// The Response Team app.
///
/// The hand-off only covers the resident-facing app, so this screen is aligned
/// to it rather than copied from it: the same ground, hairlines, coral accent
/// and uppercase headings, but arranged for someone working an incident rather
/// than reporting one. No tab bar — a responder has exactly one job on this
/// screen and a four-tab chrome would only get in the way of it.
class ResponderShell extends ConsumerWidget {
  const ResponderShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Eyebrow('Response team', color: AppColors.accent),
                        const SizedBox(height: 6),
                        Text(
                          (user?.displayName ?? 'Responder').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AgencyType.label(user?.agencyType ?? ''),
                          style: AppText.meta,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AlertsWell(
                    unread: unread,
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                      ref.invalidate(unreadCountProvider);
                    },
                  ),
                  const SizedBox(width: 8),
                  _SignOutWell(
                    onTap: () => ref.read(authProvider.notifier).signOut(),
                  ),
                ],
              ),
            ),
            const Expanded(child: ResponderHomeScreen()),
          ],
        ),
      ),
    );
  }
}

/// Take an incident, advance it, and broadcast position while travelling
/// (Section 2.5 stages 4-6).
class ResponderHomeScreen extends ConsumerWidget {
  const ResponderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(responderIncidentsProvider);
    final tracking = ref.watch(trackingProvider);

    return Column(
      children: [
        if (tracking.isBroadcasting)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: _TrackingBanner(state: tracking),
          ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.surfaceSolid,
            onRefresh: () async => ref.invalidate(responderIncidentsProvider),
            child: switch (incidents) {
              AsyncLoading() => const Center(child: CircularProgressIndicator()),
              AsyncError(:final error) => _Scroll(
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  tone: AppColors.live,
                  title: 'Could not reach dispatch',
                  body: error.toString(),
                  action: AppButton.secondary(
                    'Try again',
                    onPressed: () =>
                        ref.invalidate(responderIncidentsProvider),
                  ),
                ),
              ),
              AsyncValue(:final value?) when value.isEmpty => const _Scroll(
                child: EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  tone: AppColors.ok,
                  title: 'Nothing active',
                  body: 'Verified incidents appear here the moment a '
                      'coordinator releases them.',
                ),
              ),
              AsyncValue(:final value?) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                itemCount: value.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _IncidentCard(incident: value[i]),
              ),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ],
    );
  }
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    children: [const SizedBox(height: 40), child],
  );
}

/// Always-visible confirmation that dispatch can see this unit. A responder who
/// cannot tell whether they are being tracked will not trust the system.
class _TrackingBanner extends StatelessWidget {
  const _TrackingBanner({required this.state});

  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    final failing = state.lastError != null;
    final color = failing ? AppColors.live : AppColors.ok;

    return Panel(
      radius: AppRadius.control,
      color: color.withValues(alpha: 0.1),
      border: color.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (failing)
            const Icon(Icons.gps_off_rounded, size: 17, color: AppColors.live)
          else
            const LiveDot(color: AppColors.ok),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.lastError ??
                  'Dispatch can see your position · '
                      '${state.fixesSent} updates sent',
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentCard extends ConsumerStatefulWidget {
  const _IncidentCard({required this.incident});

  final ResponderIncident incident;

  @override
  ConsumerState<_IncidentCard> createState() => _IncidentCardState();
}

class _IncidentCardState extends ConsumerState<_IncidentCard> {
  bool _busy = false;
  String? _error;

  Future<void> _act(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inc = widget.incident;
    final actions = ref.read(responderActionsProvider.notifier);
    final color = AppColors.forStatus(inc.status);
    final confidence = (inc.confidenceScore * 100).round();

    return Panel(
      padding: const EdgeInsets.all(18),
      color: inc.isUnderway
          ? color.withValues(alpha: 0.08)
          : AppColors.surfaceDim,
      border: inc.isUnderway ? color.withValues(alpha: 0.4) : AppColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(tint: color, asset: Art.truck, size: 38, glyph: 19),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      inc.designation.toUpperCase(),
                      style: AppText.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${inc.reportCount} report'
                      '${inc.reportCount == 1 ? '' : 's'} · $confidence% confidence'
                      '${inc.activeDispatchCount > 0 ? ' · ${inc.activeDispatchCount} unit(s)' : ''}',
                      style: AppText.meta,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Tag(inc.statusLabel, color: color, dot: inc.isUnderway),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(Icons.place_outlined, size: 15, color: AppColors.faint),
              const SizedBox(width: 8),
              Text(
                '${inc.centroidLat.toStringAsFixed(5)}, '
                '${inc.centroidLng.toStringAsFixed(5)}',
                style: AppText.meta.copyWith(
                  fontFeatures: const [],
                  color: AppColors.label,
                ),
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: AppText.meta.copyWith(
                fontSize: 12,
                height: 16 / 12,
                color: AppColors.live,
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              if (inc.nextAction != null)
                Expanded(
                  child: AppButton(
                    switch (inc.nextAction!) {
                      'accept' => 'Respond to this',
                      'en_route' => 'Start travelling',
                      _ => "I've arrived",
                    },
                    height: 46,
                    busy: _busy,
                    onPressed: _busy
                        ? null
                        : () => _act(() => switch (inc.nextAction!) {
                            'accept' => actions.accept(inc.id),
                            'en_route' => actions.enRoute(inc.id),
                            _ => actions.arrived(inc.id),
                          }),
                  ),
                ),
              if (inc.isUnderway) ...[
                if (inc.nextAction != null) const SizedBox(width: 10),
                SizedBox(
                  width: inc.nextAction == null ? double.infinity : 104,
                  child: AppButton.secondary(
                    'Codes',
                    height: 46,
                    onPressed: _busy ? null : () => _openFireCodes(inc),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openFireCodes(ResponderIncident incident) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => _FireCodeSheet(incident: incident),
    );
  }
}

/// The Fire Code buttons (Section 2.5 stage 7).
///
/// Only codes this user may actually press are enabled — the server gates each
/// on target_role and target_agency, so offering the rest would produce a 403.
class _FireCodeSheet extends ConsumerWidget {
  const _FireCodeSheet({required this.incident});

  final ResponderIncident incident;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codes = ref.watch(fireCodesProvider);
    final user = ref.watch(currentUserProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetHandle()),
            Text(
              'FIRE CODES · ${incident.designation.toUpperCase()}',
              style: AppText.screenTitle,
            ),
            const SizedBox(height: 8),
            Text(
              'Logged against this incident and broadcast to dispatch. Greyed '
              'codes are not yours to press.',
              style: AppText.meta.copyWith(height: 16 / 11),
            ),
            const SizedBox(height: 18),
            switch (codes) {
              AsyncLoading() => const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
              AsyncError() => Text(
                'Could not load fire codes.',
                style: AppText.meta.copyWith(color: AppColors.live),
              ),
              AsyncValue(:final value?) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final code in value)
                    _FireCodeRow(
                      code: code,
                      incident: incident,
                      enabled: code.pressableBy(user?.role, user?.agencyType),
                    ),
                ],
              ),
              _ => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }
}

class _FireCodeRow extends ConsumerStatefulWidget {
  const _FireCodeRow({
    required this.code,
    required this.incident,
    required this.enabled,
  });

  final FireCode code;
  final ResponderIncident incident;
  final bool enabled;

  @override
  ConsumerState<_FireCodeRow> createState() => _FireCodeRowState();
}

class _FireCodeRowState extends ConsumerState<_FireCodeRow> {
  bool _busy = false;
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    final live = widget.enabled && !_sent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.4,
        child: Panel(
          radius: AppRadius.control,
          color: _sent
              ? AppColors.ok.withValues(alpha: 0.1)
              : AppColors.surfaceDim,
          border: _sent ? AppColors.ok.withValues(alpha: 0.4) : AppColors.line,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: !live || _busy
              ? null
              : () async {
                  // Captured before the await: reading it afterwards would
                  // touch a BuildContext that may no longer be mounted.
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _busy = true);
                  final failure = await ref
                      .read(responderActionsProvider.notifier)
                      .pressCode(
                        codeId: code.id,
                        incidentId: widget.incident.id,
                      );
                  if (!mounted) return;
                  setState(() {
                    _busy = false;
                    _sent = failure == null;
                  });
                  if (failure != null) {
                    messenger.showSnackBar(SnackBar(content: Text(failure)));
                  }
                },
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  code.codeNumber,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _sent ? AppColors.ok : AppColors.accent,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  code.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (_sent)
                const Icon(Icons.check_rounded, size: 17, color: AppColors.ok)
              else if (_busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertsWell extends StatelessWidget {
  const _AlertsWell({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _Well(icon: Icons.notifications_none_rounded, onTap: onTap),
        if (unread > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.live,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.bg, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SignOutWell extends StatelessWidget {
  const _SignOutWell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      _Well(icon: Icons.logout_rounded, onTap: onTap, tint: AppColors.muted);
}

class _Well extends StatelessWidget {
  const _Well({required this.icon, required this.onTap, this.tint});

  final IconData icon;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.line),
          ),
          child: Icon(icon, size: 19, color: tint ?? AppColors.text),
        ),
      ),
    );
  }
}
