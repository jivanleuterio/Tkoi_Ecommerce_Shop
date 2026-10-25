class Shop {
  final String id;
  final String ownerId;
  final String name;
  final String ownerName;
  final String description;
  final String contactNumber;
  final String email;
  final String location;
  final String? logoUrl;

  const Shop({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.ownerName,
    required this.description,
    required this.contactNumber,
    required this.email,
    required this.location,
    this.logoUrl,
  });

  factory Shop.fromMap(Map<String, dynamic> map) => Shop(
    id: map['id'] as String,
    ownerId: map['owner_id'] as String,
    name: map['name'] as String? ?? 'Fish Shop',
    ownerName: map['owner_name'] as String? ?? '',
    description: map['description'] as String? ?? '',
    contactNumber: map['contact_number'] as String? ?? '',
    email: map['email'] as String? ?? '',
    location: map['location'] as String? ?? '',
    logoUrl: map['logo_url'] as String?,
  );
}
