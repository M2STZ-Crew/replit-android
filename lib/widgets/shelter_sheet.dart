import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../location/place_names.dart';
import '../screens/directions_screen.dart';
import '../theme.dart';
import 'app_icons.dart';
import 'coordinator_kit.dart';
import 'design.dart';
import 'map_marker.dart';

/// A shelter tapped on a staff map (v1.12.56; 19 Nov 2026: "in citizen, the
/// hydrants and evacuation sites can be touched. but in coordinator and
/// responder cannot", answered "shelters and hydrants for staffs (4 wheeled
/// car)"): what it is, and directions to it by car, no incident needed.
/// Water sources have their own sheet ([openWaterSource]).
Future<void> openStaffShelter(
  BuildContext context,
  Map<String, dynamic> row,
) async {
  final lat = (row['latitude'] as num?)?.toDouble();
  final lng = (row['longitude'] as num?)?.toDouble();
  if (lat == null || lng == null) return;
  final go = await showFrameSheet<bool>(
    context,
    builder: (_) => ShelterSheet(row: row),
  );
  if (go != true || !context.mounted) return;
  await openRouteToPlace(
    context,
    lat: lat,
    lng: lng,
    name: ShelterSheet.nameOf(row),
    kind: MapMarkerKind.shelter,
  );
}

/// The shelter's name, where it is, how many it holds, who to call, and
/// Directions; pops true for Directions.
class ShelterSheet extends StatelessWidget {
  const ShelterSheet({super.key, required this.row});

  final Map<String, dynamic> row;

  static String nameOf(Map<String, dynamic> row) {
    final name = (row['name'] as String?)?.trim();
    return name == null || name.isEmpty ? t('Evacuation site') : name;
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final capacity = (row['capacity'] as num?)?.toInt();
    final address = (row['address'] as String?)?.trim();
    final city = (row['city'] as String?)?.trim();
    final contact = (row['contact_info'] as String?)?.trim();
    final where = [
      if (address != null && address.isNotEmpty) address,
      if (city != null && city.isNotEmpty && !(address ?? '').contains(city))
        city,
    ].join(', ');
    final lat = (row['latitude'] as num).toDouble();
    final lng = (row['longitude'] as num).toDouble();
    return SheetFrame(
      children: [
        Row(
          children: [
            IconWell(
              tint: pal.ok,
              icon: MapMarkerKind.shelter.glyph,
              size: 40,
              glyph: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Eyebrow(
                    row['outside_pasay'] == true
                        ? t('SHELTER · OUTSIDE PASAY')
                        : t('SHELTER'),
                    color: pal.ok,
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    header: true,
                    child: Text(nameOf(row), style: context.type.sheetTitle),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          where.isEmpty ? degrees(lat, lng) : where,
          style: context.type.bodySm.copyWith(color: pal.textSoft),
        ),
        if (capacity != null || (contact != null && contact.isNotEmpty)) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (capacity != null) t('{n} people', {'n': capacity}),
              if (contact != null && contact.isNotEmpty) contact,
            ].join(' · '),
            style: context.type.caption.copyWith(color: pal.textSoft),
          ),
        ],
        const SizedBox(height: 20),
        AppButton(
          t('Directions'),
          icon: AppIcons.directionsCar,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
