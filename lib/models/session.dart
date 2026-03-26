import 'package:equatable/equatable.dart';

class Session extends Equatable {
  final String id;
  final DateTime created;
  final DateTime? lastActivity;
  final bool isActive;
  final String description;
  final DateTime lastUpdated;
  final bool isLoadingSummary;

  const Session({
    required this.id,
    required this.created,
    this.lastActivity,
    this.isActive = false,
    this.description = '',
    DateTime? lastUpdated,
    this.isLoadingSummary = false,
  }) : lastUpdated = lastUpdated ?? created;

  factory Session.fromJson(Map<String, dynamic> json) {
    final timeMap = json['time'] ?? {};
    final created = DateTime.fromMillisecondsSinceEpoch(timeMap['created'] ?? 0);
    final updated = timeMap['updated'] != null
        ? DateTime.fromMillisecondsSinceEpoch(timeMap['updated'] ?? 0)
        : created;

    String description = json['description'] ?? '';
    if (description.isEmpty && json['title'] != null) {
      String title = json['title'] ?? '';
      
      // Clean up generic titles but keep meaningful ones
      if (title.startsWith('New Session -') ||
          (title.startsWith('Session ') && title.length < 50) ||
          title == 'Starting a new conversation' ||
          title == 'Starting new conversation' ||
          (title.length < 10 && 
           (title.toLowerCase().contains('session') || 
            title.toLowerCase().contains('chat')))) {
        description = ''; // Keep empty for generic sessions
      } else {
        description = title;
      }
    }
    
    return Session(
      id: json['id'] ?? '',
      created: created,
      lastActivity: json['lastActivity'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastActivity'] ?? 0)
          : null,
      isActive: json['isActive'] ?? false,
      description: description,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdated'] ?? 0)
          : json['lastActivity'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['lastActivity'] ?? 0)
              : updated,
      isLoadingSummary: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created': created.toIso8601String(),
      'lastActivity': lastActivity?.toIso8601String(),
      'isActive': isActive,
      'description': description,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isLoadingSummary': isLoadingSummary,
    };
  }

  Session copyWith({
    String? id,
    DateTime? created,
    DateTime? lastActivity,
    bool? isActive,
    String? description,
    DateTime? lastUpdated,
    bool? isLoadingSummary,
  }) {
    return Session(
      id: id ?? this.id,
      created: created ?? this.created,
      lastActivity: lastActivity ?? this.lastActivity,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isLoadingSummary: isLoadingSummary ?? this.isLoadingSummary,
    );
  }

  @override
  List<Object?> get props => [id, created, lastActivity, isActive, description, lastUpdated, isLoadingSummary];
}

