import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/leads/widgets/stage_badge.dart';
import 'package:buildacre_crm/features/leads/widgets/source_icon.dart';
import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/features/calls/screens/log_outcome_sheet.dart';
import 'package:buildacre_crm/features/leads/widgets/whatsapp_sheet.dart';
import 'package:buildacre_crm/features/leads/widgets/add_note_sheet.dart';
import 'package:buildacre_crm/features/leads/widgets/mark_as_lost_sheet.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';

class LeadDetailScreen extends ConsumerWidget {
  final String leadId;

  const LeadDetailScreen({super.key, required this.leadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lead = ref.watch(leadByIdProvider(leadId));
    final role = ref.watch(currentUserRoleProvider);
    final isTelecaller = role == UserRole.telecaller;
    final assignedMember = lead != null && lead.assignedTo.isNotEmpty
        ? ref.watch(memberByIdProvider(lead.assignedTo))
        : null;

    if (lead == null) {
      return const Scaffold(body: Center(child: Text('Lead not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lead.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit lead',
            onPressed: () => context.push('/leads/$leadId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Activity timeline',
            onPressed: () => context.push('/leads/$leadId/timeline'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: StageBadge(stage: lead.stage),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () => ref.read(leadsProvider.notifier).refresh(),
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LeadHeader(lead: lead),
          const SizedBox(height: 16),
          _PipelineProgress(stage: lead.stage),
          const SizedBox(height: 16),
          _LeadDetails(lead: lead, isTelecaller: isTelecaller, assignedMember: assignedMember),
          if (lead.notes != null && lead.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _NotesCard(notes: lead.notes!),
          ],
          if (lead.followupAt != null) ...[
            const SizedBox(height: 16),
            _FollowupCard(followupAt: lead.followupAt!),
          ],
          if (lead.callLogs.isNotEmpty) ...[
            const SizedBox(height: 16),
            _CallHistory(logs: lead.callLogs),
          ],
          const SizedBox(height: 16),
          _InternalNotes(lead: lead),
          const SizedBox(height: 100),
        ],
      ),
      ),
      bottomNavigationBar: _CallBar(lead: lead),
    );
  }
}

class _LeadHeader extends StatelessWidget {
  final Lead lead;

  const _LeadHeader({required this.lead});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.navy.withValues(alpha: 0.1),
          child: Text(
            lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lead.name, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  SourceIcon(source: lead.source),
                  const SizedBox(width: 8),
                  Text(
                    '${lead.source.label} · ${lead.city.label}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PipelineProgress extends StatelessWidget {
  final LeadStage stage;

  const _PipelineProgress({required this.stage});

  static const _stages = [
    LeadStage.enquiryReceived,
    LeadStage.telecallerCallDone,
    LeadStage.meetingAtOffice,
    LeadStage.siteVisit,
    LeadStage.quotationSent,
    LeadStage.negotiation,
    LeadStage.finalAgreement,
  ];

  @override
  Widget build(BuildContext context) {
    if (stage == LeadStage.lost || stage == LeadStage.future) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: stage == LeadStage.lost
              ? Colors.red.shade50
              : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: stage == LeadStage.lost
                ? Colors.red.shade200
                : Colors.amber.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              stage == LeadStage.lost
                  ? Icons.cancel_outlined
                  : Icons.schedule,
              color: stage == LeadStage.lost ? Colors.red : Colors.amber.shade700,
            ),
            const SizedBox(width: 10),
            Text(
              stage == LeadStage.lost
                  ? 'Lead marked as Lost'
                  : 'Future Client — callback scheduled',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: stage == LeadStage.lost ? Colors.red : Colors.amber.shade700,
              ),
            ),
          ],
        ),
      );
    }

    final currentIndex = _stages.indexOf(stage);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pipeline', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          Row(
            children: List.generate(_stages.length * 2 - 1, (i) {
              if (i.isOdd) {
                final stepIndex = i ~/ 2;
                final isCompleted = stepIndex < currentIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted ? AppColors.navy : AppColors.divider,
                  ),
                );
              }
              final stepIndex = i ~/ 2;
              final isCompleted = stepIndex <= currentIndex;
              final isCurrent = stepIndex == currentIndex;
              return _StepDot(
                label: _stages[stepIndex].label,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool isCompleted;
  final bool isCurrent;

  const _StepDot({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: isCurrent ? 14 : 10,
          height: isCurrent ? 14 : 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? AppColors.navy : AppColors.divider,
            border: isCurrent
                ? Border.all(color: AppColors.gold, width: 2)
                : null,
          ),
          child: isCompleted && !isCurrent
              ? const Icon(Icons.check, size: 7, color: Colors.white)
              : null,
        ),
      ],
    );
  }
}

class _LeadDetails extends StatelessWidget {
  final Lead lead;
  final bool isTelecaller;
  final TeamMember? assignedMember;

  const _LeadDetails({required this.lead, required this.isTelecaller, this.assignedMember});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lead Details', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: isTelecaller ? lead.maskedPhone : lead.phone,
          ),
          if (lead.email != null)
            _DetailRow(icon: Icons.email_outlined, label: 'Email', value: lead.email!),
          _DetailRow(icon: Icons.home_work_outlined, label: 'Service', value: lead.serviceType.label),
          _DetailRow(icon: Icons.location_city_outlined, label: 'City', value: lead.city.label),
          if (lead.area != null)
            _DetailRow(icon: Icons.location_on_outlined, label: 'Area', value: lead.area!),
          if (lead.plotSize != null)
            _DetailRow(icon: Icons.square_foot, label: 'Plot Size', value: lead.plotSize!),
          if (lead.budget != null)
            _DetailRow(icon: Icons.currency_rupee, label: 'Budget', value: lead.budget!),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Received',
            value: DateFormat('d MMM yyyy, h:mm a').format(lead.createdAt),
          ),
          if (assignedMember != null)
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Assigned To',
              value: assignedMember!.name,
              valueColor: AppColors.navy,
            ),
          if (lead.stage == LeadStage.lost && lead.lostReason != null)
            _DetailRow(
              icon: Icons.person_off_outlined,
              label: 'Lost Reason',
              value: '${lead.lostReason!.emoji} ${lead.lostReason!.label}',
              valueColor: Colors.redAccent,
            ),
          _KhataRow(lead: lead),
          _PlanningRow(lead: lead),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 13,
                    color: valueColor,
                    fontWeight: valueColor != null ? FontWeight.w600 : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  final String notes;

  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(notes, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

class _FollowupCard extends StatelessWidget {
  final DateTime followupAt;

  const _FollowupCard({required this.followupAt});

  @override
  Widget build(BuildContext context) {
    final isOverdue = followupAt.isBefore(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue ? Colors.red.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.alarm,
            color: isOverdue ? Colors.red : Colors.blue.shade600,
            size: 20,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOverdue ? 'Followup Overdue' : 'Followup Scheduled',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isOverdue ? Colors.red : Colors.blue.shade700,
                  fontSize: 13,
                ),
              ),
              Text(
                DateFormat('EEEE, d MMM · h:mm a').format(followupAt),
                style: TextStyle(
                  fontSize: 12,
                  color: isOverdue ? Colors.red.shade400 : Colors.blue.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallHistory extends StatelessWidget {
  final List<CallLog> logs;

  const _CallHistory({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Call History', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...logs.reversed.map((log) => _CallLogTile(log: log)),
        ],
      ),
    );
  }
}

class _CallLogTile extends StatelessWidget {
  final CallLog log;

  const _CallLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: log.isSuspiciouslyShort
                  ? Colors.red.shade50
                  : AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              log.isSuspiciouslyShort ? Icons.warning_amber : Icons.call_made,
              size: 16,
              color: log.isSuspiciouslyShort ? Colors.red : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('d MMM, h:mm a').format(log.calledAt),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      log.formattedDuration,
                      style: TextStyle(
                        fontSize: 11,
                        color: log.isSuspiciouslyShort
                            ? Colors.red
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.outcome.label,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
                if (log.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    log.notes!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallBar extends ConsumerWidget {
  final Lead lead;

  const _CallBar({required this.lead});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActiveStage = lead.stage != LeadStage.lost &&
        lead.stage != LeadStage.finalAgreement;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          // WhatsApp button
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.chat, color: Colors.white, size: 20),
              tooltip: 'Send WhatsApp',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => WhatsAppSheet(lead: lead),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isActiveStage
                  ? () => _initiateCall(context, ref)
                  : null,
              icon: const Icon(Icons.call, size: 20),
              label: const Text('Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (lead.stage == LeadStage.negotiation)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _markWon(context, ref),
                icon: const Icon(Icons.emoji_events_outlined, size: 18),
                label: const Text('Won!'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.stageWon,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          else
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showStageSelector(context, ref),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Update Stage'),
              ),
            ),
        ],
      ),
    );
  }

  void _markWon(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as Won? 🏆'),
        content: Text('Move ${lead.name} to Final Agreement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stageWon,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.read(leadsProvider.notifier).updateStage(lead.id, LeadStage.finalAgreement);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('🏆 Deal won! Congratulations!'),
                backgroundColor: AppColors.stageWon,
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: const Text('Mark Won'),
          ),
        ],
      ),
    );
  }

  void _initiateCall(BuildContext context, WidgetRef ref) {
    // TODO: trigger Exotel click-to-call API
    // For now, show the log outcome sheet immediately (simulating call end)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => LogOutcomeSheet(leadId: lead.id),
    );
  }

  void _showStageSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _StageSelectorSheet(lead: lead, ref: ref),
    );
  }
}

class _StageSelectorSheet extends StatelessWidget {
  final Lead lead;
  final WidgetRef ref;

  const _StageSelectorSheet({required this.lead, required this.ref});

  @override
  Widget build(BuildContext context) {
    const stages = [
      LeadStage.enquiryReceived,
      LeadStage.telecallerCallDone,
      LeadStage.meetingAtOffice,
      LeadStage.siteVisit,
      LeadStage.quotationSent,
      LeadStage.negotiation,
      LeadStage.finalAgreement,
      LeadStage.lost,
      LeadStage.future,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Move to Stage', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...stages.map((s) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: StageBadge(stage: s),
                trailing: lead.stage == s
                    ? const Icon(Icons.check_circle, color: AppColors.navy)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  if (s == LeadStage.lost) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => MarkAsLostSheet(
                        leadId: lead.id,
                        leadName: lead.name,
                      ),
                    );
                  } else {
                    ref.read(leadsProvider.notifier).updateStage(lead.id, s);
                  }
                },
              )),
        ],
      ),
    );
  }
}

class _InternalNotes extends ConsumerWidget {
  final Lead lead;
  const _InternalNotes({required this.lead});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = lead.internalNotes.reversed.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_outlined,
                  size: 16, color: AppColors.navy),
              const SizedBox(width: 6),
              Text('Internal Notes',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 14)),
              const Spacer(),
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AddNoteSheet(leadId: lead.id),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Add Note',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (notes.isEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'No notes yet. Add context, manager instructions, or reminders.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...notes.indexed.map((entry) {
              final i = entry.$1;
              final note = entry.$2;
              final isManagerNote = note.authorId == 'mgr_1' ||
                  note.authorId == 'adm_1';
              return Column(
                children: [
                  if (i > 0) const Divider(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isManagerNote
                              ? AppColors.gold.withValues(alpha: 0.15)
                              : AppColors.navy.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            note.authorName[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isManagerNote
                                  ? AppColors.gold
                                  : AppColors.navy,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  note.authorName.split(' ').first,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isManagerNote
                                        ? AppColors.gold
                                        : AppColors.navy,
                                  ),
                                ),
                                if (isManagerNote) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Manager',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: AppColors.gold,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  _timeAgo(note.createdAt),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              note.text,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _PlanningRow extends ConsumerWidget {
  final Lead lead;
  const _PlanningRow({required this.lead});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.schedule_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            SizedBox(
              width: 80,
              child: Text('Planning',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 13)),
            ),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: PlanningTimeline.values.map((t) {
                  final isSelected = lead.planningTimeline == t;
                  final color = t.isUrgent ? Colors.redAccent : AppColors.navy;
                  return GestureDetector(
                    onTap: () {
                      final newVal = isSelected ? null : t;
                      ref
                          .read(leadsProvider.notifier)
                          .updatePlanningTimeline(lead.id, newVal);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.1)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? color : AppColors.divider,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t.emoji,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 5),
                          Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? color
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _KhataRow extends ConsumerWidget {
  final Lead lead;
  const _KhataRow({required this.lead});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.article_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            SizedBox(
              width: 80,
              child: Text('Khata',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 13)),
            ),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: KhataType.values.map((k) {
                  final isSelected = lead.khataType == k;
                  final isQuick = k.isQuickStart;
                  return GestureDetector(
                    onTap: () {
                      // Toggle: tap selected to deselect
                      final newVal = isSelected ? null : k;
                      ref.read(leadsProvider.notifier).updateKhata(lead.id, newVal);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isQuick
                                ? AppColors.stageWon.withValues(alpha: 0.12)
                                : AppColors.navy.withValues(alpha: 0.08))
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? (isQuick
                                  ? AppColors.stageWon
                                  : AppColors.navy)
                              : AppColors.divider,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        k.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? (isQuick
                                  ? AppColors.stageWon
                                  : AppColors.navy)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        if (lead.khataType != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              lead.khataType!.description,
              style: TextStyle(
                fontSize: 11,
                color: lead.khataType!.isQuickStart
                    ? AppColors.stageWon
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
