import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import 'app_updates.dart';
import 'update_nudge.dart';

/// "There's a new update!" on a home screen, while a newer release is waiting
/// ([UpdateNudge.waiting]); nothing at all otherwise.
///
/// It stays until it is acted on: UPDATE, or a tap anywhere on it, opens
/// Check for updates on Android; × keeps it away until a newer release. An
/// iPhone cannot install from the app, so it is told to use Sideloadly, as
/// before, and has only ×.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, this.padding = EdgeInsets.zero});

  /// Around the banner when it shows, so a screen's spacing goes with it.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AvailableRelease?>(
      valueListenable: UpdateNudge.waiting,
      builder: (context, release, _) => release == null
          ? const SizedBox.shrink()
          : Padding(
              padding: padding,
              child: _UpdateCard(release: release),
            ),
    );
  }
}

/// A home screen with its own layout under the status bar (the coordinator's
/// Queue, the responder's Duty), with the banner above it while one is
/// waiting and [visible]. The screen moves down rather than being covered, and
/// stays the same screen: its state survives the banner coming and going.
class UpdateBannerSlot extends StatelessWidget {
  const UpdateBannerSlot({super.key, required this.child, this.visible = true});

  final Widget child;

  /// False on the shell's other tabs: the banner belongs on the home one.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AvailableRelease?>(
      valueListenable: UpdateNudge.waiting,
      child: child,
      builder: (context, release, child) {
        final show = visible && release != null;
        return Column(
          children: [
            if (show)
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  child: _UpdateCard(release: release),
                ),
              ),
            Expanded(
              key: const ValueKey('update-banner-slot'),
              // The banner took the status bar's room; the screen below
              // starts under the banner, not under the status bar again.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: show,
                child: child!,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.release});

  final AvailableRelease release;

  @override
  Widget build(BuildContext context) {
    final install = AppUpdates.supported;
    void open() => unawaited(showUpdateSheet(context));
    const ink = AppColors.accentText;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: install ? open : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 2, 8),
              child: Row(
                children: [
                  const Icon(AppIcons.download, color: ink, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t("There's a new update!"),
                          style: const TextStyle(
                            color: ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          install
                              ? t('RepLiT {version} is ready to install.', {
                                  'version': release.version,
                                })
                              : t(
                                  'RepLiT {version} is out. Install it with '
                                  'Sideloadly, as before.',
                                  {'version': release.version},
                                ),
                          style: const TextStyle(color: ink, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (install)
                    TextButton(
                      onPressed: open,
                      style: TextButton.styleFrom(
                        foregroundColor: ink,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(48, 40),
                      ),
                      child: Text(
                        t('UPDATE'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: t('Close'),
                    onPressed: () => unawaited(UpdateNudge.close()),
                    icon: const Icon(AppIcons.close, color: ink, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
