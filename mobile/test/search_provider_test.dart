import 'package:flutter_test/flutter_test.dart';
import 'package:aldeia_indica/features/providers_list/providers/search_provider.dart';

void main() {
  group('parseServiceCategories', () {
    test('maps provider_count from the backend into ServiceCategory', () {
      final result = parseServiceCategories([
        {
          'id': 1,
          'slug': 'diarista',
          'name_pt': 'Diarista',
          'icon_name': 'cleaning_services',
          'provider_count': 3,
        },
      ]);

      expect(result, hasLength(1));
      expect(result.first.slug, 'diarista');
      expect(result.first.namePt, 'Diarista');
      expect(result.first.iconName, 'cleaning_services');
      expect(result.first.providerCount, 3);
    });

    test('defaults provider_count to 0 when the field is missing', () {
      final result = parseServiceCategories([
        {'id': 2, 'slug': 'jardineiro', 'name_pt': 'Jardineiro', 'icon_name': null},
      ]);

      expect(result.first.providerCount, 0);
    });

    test('preserves order and handles multiple categories', () {
      final result = parseServiceCategories([
        {'id': 1, 'slug': 'a', 'name_pt': 'A', 'icon_name': null, 'provider_count': 5},
        {'id': 2, 'slug': 'b', 'name_pt': 'B', 'icon_name': null, 'provider_count': 0},
      ]);

      expect(result.map((c) => c.slug), ['a', 'b']);
    });
  });
}
