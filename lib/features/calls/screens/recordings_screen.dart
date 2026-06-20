import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/leads/providers/filtered_leads_provider.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';

// Flat record joining call log + lead context
class _CallRecord {
  final CallLog log;
  final Lead lead;
  final TeamMember telecaller;

  const _CallRecord({required this.log, required this.lead, required this.telecaller});
}

final _recordingsProvider = Provider<List<_CallRecord>>((ref) {
  // Use dedicated provider — fetches ALL leads that have call logs from Supabase
  final leads = ref.watch(recordingsLeadsProvider);
  final tcMap = {for (final tc in ref.watch(profilesProvider)) tc.id: tc};

  final records = <_CallRecord>[];
  for (final lead in leads) {
    final tc = tcMap[lead.assignedTo];
    for (final log in lead.callLogs) {
      records.add(_CallRecord(
        log: log,
        lead: lead,
        telecaller: tc ?? TeamMember(
          id: lead.assignedTo,
          name: 'Unknown',
          email: '',
          role: UserRole.telecaller,
        ),
      ));
    }
  }
  records.sort((a, b) => b.log.calledAt.compareTo(a.log.calledAt));
  return records;
});

class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  String? _selectedTcId;  // null = all
  bool _suspiciousOnly = false;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(_recordingsProvider);

    var filtered = all.where((r) {
      if (_selectedTcId != null && r.telecaller.id != _selectedTcId) return false;
      if (_suspiciousOnly && !r.log.isSuspiciouslyShort) return false;
      return true;
    }).toList();

    final suspiciousCount = all.where((r) => r.log.isSuspiciouslyShort).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Call Recordings')),
      body: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () => ref.read(recordingsLeadsProvider.notifier).refresh(),
        child: Column(
          children: [
            _buildHeader(context, all.length, suspiciousCount),
            _buildFilters(context),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _CallCard(record: filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int total, int suspicious) {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          _HeaderStat(label: 'Total Calls', value: '$total'),
          const SizedBox(width: 24),
          GestureDetector(
            onTap: () => setState(() => _suspiciousOnly = !_suspiciousOnly),
            child: _HeaderStat(
              label: 'Short (<30s)',
              value: '$suspicious',
              highlight: suspicious > 0,
              underline: _suspiciousOnly,
            ),
          ),
          const Spacer(),
          if (suspicious > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Review needed',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Container(
      color: AppColors.navy,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All Reps',
                  selected: _selectedTcId == null,
                  onTap: () => setState(() => _selectedTcId = null),
                ),
                const SizedBox(width: 8),
                ...ref.watch(telecallersProvider).map((tc) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: tc.firstName,
                    selected: _selectedTcId == tc.id,
                    onTap: () => setState(() => _selectedTcId = tc.id),
                  ),
                )),
              ],
            ),
          ),
          if (_suspiciousOnly)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    'Showing short calls only',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _suspiciousOnly = false),
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_missed, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('No calls match this filter', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _CallCard extends StatelessWidget {
  final _CallRecord record;
  const _CallCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final log = record.log;
    final lead = record.lead;
    final tc = record.telecaller;
    final isSuspicious = log.isSuspiciouslyShort;

    return GestureDetector(
      onTap: () => context.push('/leads/${lead.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSuspicious ? Colors.red.shade200 : AppColors.divider,
            width: isSuspicious ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _OutcomeIcon(outcome: log.outcome),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          '${lead.serviceType.label} · ${lead.city.label}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (isSuspicious)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Short call',
                        style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MetaPill(icon: Icons.person_outline, label: tc.name.split(' ').first),
                  const SizedBox(width: 12),
                  _MetaPill(
                    icon: Icons.timer_outlined,
                    label: log.formattedDuration,
                    color: isSuspicious ? Colors.red : null,
                  ),
                  const SizedBox(width: 12),
                  _MetaPill(icon: Icons.calendar_today_outlined, label: _formatDate(log.calledAt)),
                  const Spacer(),
                  _OutcomePill(outcome: log.outcome),
                ],
              ),
              if (log.notes != null && log.notes!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    log.notes!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
              if (log.recordingUrl != null) ...[
                const SizedBox(height: 10),
                _PlayButton(url: log.recordingUrl!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today ${DateFormat('h:mm a').format(dt)}';
    if (d == yesterday) return 'Yesterday ${DateFormat('h:mm a').format(dt)}';
    return DateFormat('d MMM, h:mm a').format(dt);
  }
}

class _OutcomeIcon extends StatelessWidget {
  final CallOutcome outcome;
  const _OutcomeIcon({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (outcome) {
      CallOutcome.interested    => (Icons.thumb_up_outlined, AppColors.stageWon),
      CallOutcome.notInterested => (Icons.thumb_down_outlined, AppColors.stageLost),
      CallOutcome.callback      => (Icons.schedule, AppColors.stageCalled),
      CallOutcome.notReachable  => (Icons.phone_missed_outlined, AppColors.textSecondary),
      CallOutcome.future        => (Icons.hourglass_empty, AppColors.stageMeeting),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _OutcomePill extends StatelessWidget {
  final CallOutcome outcome;
  const _OutcomePill({required this.outcome});

  Color get _color {
    return switch (outcome) {
      CallOutcome.interested    => AppColors.stageWon,
      CallOutcome.notInterested => AppColors.stageLost,
      CallOutcome.callback      => AppColors.stageCalled,
      CallOutcome.notReachable  => AppColors.textSecondary,
      CallOutcome.future        => AppColors.stageMeeting,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        outcome.label,
        style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MetaPill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}

class _PlayButton extends StatefulWidget {
  final String url;
  const _PlayButton({required this.url});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _playing = !_playing);
        if (_playing) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _playing = false);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _playing ? Icons.pause_circle_outline : Icons.play_circle_outline,
              size: 18,
              color: AppColors.navy,
            ),
            const SizedBox(width: 6),
            Text(
              _playing ? 'Playing...' : 'Play Recording',
              style: const TextStyle(fontSize: 12, color: AppColors.navy, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool underline;
  const _HeaderStat({required this.label, required this.value, this.highlight = false, this.underline = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: highlight ? Colors.redAccent : Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            decoration: underline ? TextDecoration.underline : null,
            decorationColor: Colors.white54,
          ),
        ),
      ],
    );
  }
}
