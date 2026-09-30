import 'package:flutter_test/flutter_test.dart';

import 'package:replit/screens/responder/responder_status.dart';

/// Staff see who verified an incident and for which team (v1.12.1).
void main() {
  test('names the person and their team', () {
    expect(
      verifierLine({
        'verified_by_name': 'Ramon Dizon',
        'verified_by_organization': 'Hercules Fire Brigade',
        'verified_by_agency': 'fire_volunteer',
      }),
      'Ramon Dizon · Hercules Fire Brigade',
    );
  });

  test('falls back to the agency, then to Admin', () {
    expect(
      verifierLine({'verified_by_name': 'Ana Cruz', 'verified_by_agency': 'bfp'}),
      'Ana Cruz · BFP',
    );
    expect(verifierLine({'verified_by_name': 'Admin One'}), 'Admin One · Admin');
  });

  test('says nothing until someone has verified it', () {
    expect(verifierLine({'status': 'reported'}), isNull);
    expect(verifierLine(null), isNull);
  });
}
