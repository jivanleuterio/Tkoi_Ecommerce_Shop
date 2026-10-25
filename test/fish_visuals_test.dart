import 'package:flutter_test/flutter_test.dart';
import 'package:tkoi_shop/utils/fish_visuals.dart';

void main() {
  group('FishVisuals', () {
    test('matches listing categories to bundled fish artwork', () {
      expect(FishVisuals.forFish(category: 'Koi'), FishVisuals.koi);
      expect(
        FishVisuals.forFish(name: 'Dalmatian Molly'),
        FishVisuals.guppyMolly,
      );
      expect(
        FishVisuals.forFish(species: 'Silver Arowana'),
        FishVisuals.arowana,
      );
      expect(FishVisuals.forFish(category: 'Marine Fish'), FishVisuals.marine);
    });

    test('uses a friendly tropical visual for unknown fish', () {
      expect(FishVisuals.forFish(name: 'Mystery fish'), FishVisuals.guppyMolly);
    });
  });
}
