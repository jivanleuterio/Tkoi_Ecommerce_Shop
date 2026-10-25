class AppProfile {
  final String id;
  final String fullName;
  final String username;
  final String email;
  final String mobileNumber;
  final String address;
  final String? avatarUrl;

  const AppProfile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.mobileNumber,
    required this.address,
    this.avatarUrl,
  });

  factory AppProfile.fromMap(Map<String, dynamic> map) => AppProfile(
    id: map['id'] as String,
    fullName: map['full_name'] as String? ?? '',
    username: map['username'] as String? ?? '',
    email: map['email'] as String? ?? '',
    mobileNumber: map['mobile_number'] as String? ?? '',
    address: map['address'] as String? ?? '',
    avatarUrl: map['avatar_url'] as String?,
  );
}
