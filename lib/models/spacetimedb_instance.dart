import 'package:uuid/uuid.dart';

class SpacetimeDbInstance {
  final String id;
  final String name;
  final String ip;
  final String port;
  final String database;
  final String? authToken;
  final DateTime createdAt;
  final DateTime lastUsed;

  SpacetimeDbInstance({
    String? id,
    required this.name,
    required this.ip,
    required this.port,
    required this.database,
    this.authToken,
    DateTime? createdAt,
    DateTime? lastUsed,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        lastUsed = lastUsed ?? DateTime.now();

  /// Get the full host string (ip:port)
  String get host => '$ip:$port';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'database': database,
      'authToken': authToken,
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed.toIso8601String(),
    };
  }

  factory SpacetimeDbInstance.fromJson(Map<String, dynamic> json) {
    // Handle legacy format where host was stored as "ip:port"
    String ip;
    String port;

    if (json.containsKey('ip') && json.containsKey('port')) {
      // New format
      ip = json['ip'];
      port = json['port'];
    } else if (json.containsKey('host')) {
      // Legacy format - split host into ip:port
      final hostParts = (json['host'] as String).split(':');
      ip = hostParts[0];
      port = hostParts.length > 1 ? hostParts[1] : '3000';
    } else {
      throw Exception('Invalid SpacetimeDbInstance JSON: missing ip/port or host');
    }

    return SpacetimeDbInstance(
      id: json['id'],
      name: json['name'],
      ip: ip,
      port: port,
      database: json['database'],
      authToken: json['authToken'],
      createdAt: DateTime.parse(json['createdAt']),
      lastUsed: DateTime.parse(json['lastUsed']),
    );
  }

  SpacetimeDbInstance copyWith({
    String? id,
    String? name,
    String? ip,
    String? port,
    String? database,
    String? authToken,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return SpacetimeDbInstance(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      database: database ?? this.database,
      authToken: authToken ?? this.authToken,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpacetimeDbInstance && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SpacetimeDbInstance(id: $id, name: $name, ip: $ip, port: $port, database: $database)';
  }
}
