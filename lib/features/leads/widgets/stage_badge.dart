import 'package:flutter/material.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';

class StageBadge extends StatelessWidget {
  final LeadStage stage;
  final bool compact;

  const StageBadge({super.key, required this.stage, this.compact = false});

  Color get _color {
    switch (stage) {
      case LeadStage.enquiryReceived:    return AppColors.stageEnquiry;
      case LeadStage.telecallerCallDone: return AppColors.stageCalled;
      case LeadStage.meetingAtOffice:    return AppColors.stageMeeting;
      case LeadStage.siteVisit:          return AppColors.stageSiteVisit;
      case LeadStage.quotationSent:      return AppColors.stageQuotation;
      case LeadStage.negotiation:        return AppColors.stageNegotiation;
      case LeadStage.finalAgreement:     return AppColors.stageWon;
      case LeadStage.lost:               return AppColors.stageLost;
      case LeadStage.future:             return AppColors.stageMeeting;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        stage.label,
        style: TextStyle(
          color: _color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
