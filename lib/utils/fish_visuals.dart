class FishVisuals {
  static const String koi = 'assets/images/fish/koi.jpg';
  static const String goldfish = 'assets/images/fish/goldfish.jpg';
  static const String betta = 'assets/images/fish/betta.jpg';
  static const String guppyMolly = 'assets/images/fish/guppy-molly.jpg';
  static const String cichlid = 'assets/images/fish/cichlid.jpg';
  static const String arowana = 'assets/images/fish/arowana.jpg';
  static const String catfish = 'assets/images/fish/catfish.jpg';
  static const String marine = 'assets/images/fish/marine.jpg';

  static String forFish({String? category, String? species, String? name}) {
    final description = '${category ?? ''} ${species ?? ''} ${name ?? ''}'
        .toLowerCase();

    if (description.contains('goldfish') ||
        description.contains('oranda') ||
        description.contains('ranchu')) {
      return goldfish;
    }
    if (description.contains('betta') ||
        description.contains('fighting fish')) {
      return betta;
    }
    if (description.contains('guppy') ||
        description.contains('molly') ||
        description.contains('platy') ||
        description.contains('swordtail')) {
      return guppyMolly;
    }
    if (description.contains('cichlid') ||
        description.contains('oscar') ||
        description.contains('flowerhorn')) {
      return cichlid;
    }
    if (description.contains('arowana')) return arowana;
    if (description.contains('catfish') ||
        description.contains('pleco') ||
        description.contains('cory')) {
      return catfish;
    }
    if (description.contains('marine') ||
        description.contains('saltwater') ||
        description.contains('clownfish')) {
      return marine;
    }
    if (description.contains('koi') || description.contains('carp')) {
      return koi;
    }
    return guppyMolly;
  }
}
