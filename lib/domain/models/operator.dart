/// A logged-in operator — the person, not the device (spec
/// 022-backend-sync-fundacao). Mirrors the backend's public `Operator`
/// shape (`sonho-de-crianca-backend`, `specs/001-fundacao-auth-crud`):
/// never carries a password/hash, only what's safe to keep on-device
/// alongside the session token.
class Operator {
  const Operator({required this.id, required this.name, required this.username});

  final String id;
  final String name;
  final String username;

  factory Operator.fromJson(Map<String, dynamic> json) => Operator(
        id: json['id'] as String,
        name: json['name'] as String,
        username: json['username'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'username': username};
}
