import 'package:flutter/material.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';

class SourceIcon extends StatelessWidget {
  final LeadSource source;

  const SourceIcon({super.key, required this.source});

  IconData get _icon {
    switch (source) {
      case LeadSource.facebook:  return Icons.facebook;
      case LeadSource.instagram: return Icons.camera_alt_outlined;
      case LeadSource.website:   return Icons.language;
      case LeadSource.phone:     return Icons.call;
      case LeadSource.whatsapp:  return Icons.chat;
      case LeadSource.referral:  return Icons.people;
    }
  }

  Color get _color {
    switch (source) {
      case LeadSource.facebook:  return const Color(0xFF1877F2);
      case LeadSource.instagram: return const Color(0xFFE1306C);
      case LeadSource.website:   return AppColors.navy;
      case LeadSource.phone:     return AppColors.stageWon;
      case LeadSource.whatsapp:  return const Color(0xFF25D366);
      case LeadSource.referral:  return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_icon, size: 16, color: _color),
    );
  }
}
