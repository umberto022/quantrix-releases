class QuantrixUser {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String plan; // free | pro
  final DateTime createdAt;

  const QuantrixUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.plan = 'free',
    required this.createdAt,
  });

  bool get isPro => plan == 'pro';

  QuantrixUser copyWith({String? name, String? avatarUrl, String? plan}) {
    return QuantrixUser(
      id: id,
      name: name ?? this.name,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      plan: plan ?? this.plan,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'plan': plan,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QuantrixUser.fromJson(Map<String, dynamic> json) => QuantrixUser(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        avatarUrl: json['avatarUrl'],
        plan: json['plan'] ?? 'free',
        createdAt: DateTime.parse(json['createdAt']),
      );
}
