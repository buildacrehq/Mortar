import 'package:flutter/material.dart';

enum NotificationType { alert, assignment, callQuality, stageUpdate, futureDue }

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? leadId;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.leadId,
    this.isRead = false,
  });

  IconData get icon {
    switch (type) {
      case NotificationType.alert:       return Icons.warning_amber_outlined;
      case NotificationType.assignment:  return Icons.assignment_ind_outlined;
      case NotificationType.callQuality: return Icons.phone_missed_outlined;
      case NotificationType.stageUpdate: return Icons.moving_outlined;
      case NotificationType.futureDue:   return Icons.hourglass_top_outlined;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.alert:       return Colors.redAccent;
      case NotificationType.assignment:  return const Color(0xFF6366F1);
      case NotificationType.callQuality: return Colors.orangeAccent;
      case NotificationType.stageUpdate: return const Color(0xFF10B981);
      case NotificationType.futureDue:   return const Color(0xFFF5A623);
    }
  }

  String get typeLabel {
    switch (type) {
      case NotificationType.alert:       return 'Alert';
      case NotificationType.assignment:  return 'Assignment';
      case NotificationType.callQuality: return 'Call Quality';
      case NotificationType.stageUpdate: return 'Stage Update';
      case NotificationType.futureDue:   return 'Future Due';
    }
  }
}
