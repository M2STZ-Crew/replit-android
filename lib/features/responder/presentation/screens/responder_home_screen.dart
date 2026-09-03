import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/responder_incident.dart';
import '../providers/responder_provider.dart';
import '../providers/tracking_provider.dart';

/// The Response Team's operational screen: take an incident, advance it, and
/// broadcast position while travelling (Section 2.5 stages 4-6).
class ResponderHomeScreen extends ConsumerWidget {
  const ResponderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(responderIncidentsProvider);
    final tracking = ref.watch(trackingProvider);

    return Column(
      children: [
        if (tracking.isBroadcasting) _TrackingBanner(state: tracking),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(responderIncidentsProvider),
            child: switch (incidents) {
              AsyncLoading() => const Center(child: CircularProgressIndicator()),
              AsyncError(:final error) => _Message(
                  icon: Icons.cloud_off,
                  text: error.toString(),
                  onRetry: () => ref.invalidate(responderIncidentsProvider),
                ),
              AsyncValue(:final value?) when value.isEmpty => const _Message(
                  icon: Icons.check_circle_outline,
                  text: 'No active incidents.\n\n'
                      'Verified incidents appear here for you to respond to.',
                ),
              AsyncValue(:final value?) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: value.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
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

/// Always-visible confirmation that dispatch can see this unit. A responder who
/// cannot tell whether they are being tracked will not trust the system.
class _TrackingBanner extends StatelessWidget {
  const _TrackingBanner({required this.state});

  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    final failing = state.lastError != null;
    return Container(
      width: double.infinity,
      color: failing
          ? AppColors.error.withValues(alpha: 0.12)
          : AppColors.success.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            failing ? Icons.gps_off : Icons.gps_fixed,
            size: 18,
            color: failing ? AppColors.error : AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.lastError ??
                  'Dispatch can see your position · ${state.fixesSent} updates sent',
              style: TextStyle(
                fontSize: 13,
                color: failing ? AppColors.error : AppColors.success,
                fontWeight: FontWeight.w600,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(inc.designation,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  inc.statusLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${inc.reportCount} report${inc.reportCount == 1 ? '' : 's'} · '
            '${(inc.confidenceScore * 100).round()}% confidence'
            '${inc.activeDispatchCount > 0 ? ' · ${inc.activeDispatchCount} unit(s) responding' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            'Centroid ${inc.centroidLat.toStringAsFixed(5)}, '
            '${inc.centroidLng.toStringAsFixed(5)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (inc.nextAction != null)
                Expanded(
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _act(() => switch (inc.nextAction!) {
                              'accept' => actions.accept(inc.id),
                              'en_route' => actions.enRoute(inc.id),
                              _ => actions.arrived(inc.id),
                            }),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: Text(_busy
                        ? 'Working…'
                        : switch (inc.nextAction!) {
                            'accept' => 'Respond to this',
                            'en_route' => 'Start travelling',
                            _ => "I've arrived",
                          }),
                  ),
                ),
              if (inc.isUnderway) ...[
                if (inc.nextAction != null) const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _busy ? null : () => _openFireCodes(inc),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(90, 46),
                  ),
                  child: const Text('Codes'),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fire codes · ${incident.designation}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Logged against this incident and broadcast to dispatch.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            switch (codes) {
              AsyncLoading() => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              AsyncError() => const Text('Could not load fire codes.'),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: !widget.enabled || _busy || _sent
            ? null
            : () async {
                // Captured before the await: reading it afterwards would touch a
                // BuildContext that may no longer be mounted.
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _busy = true);
                final failure = await ref
                    .read(responderActionsProvider.notifier)
                    .pressCode(codeId: code.id, incidentId: widget.incident.id);
                if (!mounted) return;
                setState(() {
                  _busy = false;
                  _sent = failure == null;
                });
                if (failure != null) {
                  messenger.showSnackBar(SnackBar(content: Text(failure)));
                }
              },
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(code.codeNumber,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(child: Text(code.name, textAlign: TextAlign.left)),
            if (_sent)
              const Icon(Icons.check, size: 18, color: AppColors.success)
            else if (_busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(36),
      children: [
        const SizedBox(height: 70),
        Icon(icon, size: 52, color: Colors.black26),
        const SizedBox(height: 16),
        Text(text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium),
        if (onRetry != null) ...[
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ],
      ],
    );
  }
}
