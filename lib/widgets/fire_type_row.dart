import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../i18n/i18n.dart';
import '../models/area_view.dart';
import '../theme.dart';
import 'app_icons.dart';
import 'coordinator_kit.dart';
import 'field_ops.dart';

/// "What's burning?" on a live incident (PRD v14 §4.5.3; Figma C11 / R09,
/// C18 / R08b): once a unit is on scene it is asked, and it stays asked —
/// a red row at the top of the sheet — until someone answers; then the row
/// names the fire type, and a tap corrects it.
class FireTypeRow extends StatelessWidget {
  const FireTypeRow({super.key, required this.area, this.onPick});

  final AreaView area;

  /// Opens the picker; null where this person may not set it.
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fire = area.fireType;
    if (fire == null) {
      return ListRow(
        key: const ValueKey('fire-type-ask'),
        leading: IconPlate(AppIcons.localFireDepartment, tint: pal.live),
        title: t('What’s burning?'),
        subtitle: onPick == null
            ? t('Waiting for the unit on scene to say')
            : t('Required on scene. Pick the fire type.'),
        chevron: onPick != null,
        onTap: onPick,
      );
    }
    return ListRow(
      key: const ValueKey('fire-type-set'),
      leading: const IconPlate(AppIcons.localFireDepartment),
      title: t('Fire type'),
      subtitle: fire.label,
      chevron: onPick != null,
      onTap: onPick,
    );
  }
}

/// Asks "What's burning?" and saves the answer. True when it was saved;
/// false when the sheet was put away, or saving failed (said in a snack bar).
Future<bool> askFireType(
  BuildContext context, {
  required ApiClient api,
  required AreaView area,
}) async {
  final arrived = area.at('arrived_at');
  final picked = await showFireTypeSheet(
    context,
    areaLabel: area.name,
    arrivedAt: arrived == null ? null : clockText(arrived),
  );
  if (picked == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await api.setFireType(area.id, picked);
    messenger.showSnackBar(
      SnackBar(
        content: Text(t('Fire type set: {label}.', {'label': picked.label})),
      ),
    );
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          t('Could not save the fire type. Check your connection.'),
        ),
      ),
    );
  }
  return false;
}
