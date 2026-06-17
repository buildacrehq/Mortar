import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';

class LogOutcomeSheet extends ConsumerStatefulWidget {
  final String leadId;

  const LogOutcomeSheet({super.key, required this.leadId});

  @override
  ConsumerState<LogOutcomeSheet> createState() => _LogOutcomeSheetState();
}

class _LogOutcomeSheetState extends ConsumerState<LogOutcomeSheet> {
  CallOutcome? _outcome;
  FutureTag? _futureTag;
  final _notesController = TextEditingController();
  DateTime? _followupDate;
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFollowupDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _followupDate = picked);
  }

  Future<void> _save() async {
    if (_outcome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a call outcome')),
      );
      return;
    }
    setState(() => _saving = true);
    ref.read(leadsProvider.notifier).logCall(
          leadId: widget.leadId,
          durationSeconds: 0, // TODO: real duration from Exotel webhook
          outcome: _outcome!,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          followupAt: _followupDate,
          futureTag: _futureTag,
        );
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          const SizedBox(height: 4),
          Text('Log Call Outcome', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('What happened on this call?',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          _buildOutcomeSelector(),
          if (_outcome == CallOutcome.future) ...[
            const SizedBox(height: 16),
            _buildFutureTagSelector(),
          ],
          const SizedBox(height: 16),
          _buildFollowupRow(),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
              hintText: 'Budget, requirements, client mood…',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save & Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildOutcomeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CallOutcome.values.map((outcome) {
        final selected = _outcome == outcome;
        return GestureDetector(
          onTap: () => setState(() {
            _outcome = outcome;
            if (outcome != CallOutcome.future) _futureTag = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _outcomeColor(outcome) : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? _outcomeColor(outcome) : AppColors.divider,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _outcomeIcon(outcome),
                  size: 15,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  outcome.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFutureTagSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Timeline', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: FutureTag.values.map((tag) {
            final selected = _futureTag == tag;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _futureTag = tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.gold : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppColors.gold : AppColors.divider,
                    ),
                  ),
                  child: Text(
                    _futureTagLabel(tag),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFollowupRow() {
    return GestureDetector(
      onTap: _pickFollowupDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _followupDate != null
              ? AppColors.navy.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                _followupDate != null ? AppColors.navy : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.alarm_add_outlined,
              size: 18,
              color:
                  _followupDate != null ? AppColors.navy : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(
              _followupDate != null
                  ? 'Followup: ${_formatDate(_followupDate!)}'
                  : 'Set followup date (optional)',
              style: TextStyle(
                fontSize: 14,
                color: _followupDate != null
                    ? AppColors.navy
                    : AppColors.textSecondary,
                fontWeight: _followupDate != null
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
            if (_followupDate != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _followupDate = null),
                child: const Icon(Icons.clear, size: 16, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _outcomeColor(CallOutcome outcome) {
    switch (outcome) {
      case CallOutcome.interested:    return AppColors.stageWon;
      case CallOutcome.notInterested: return AppColors.stageLost;
      case CallOutcome.callback:      return AppColors.stageCalled;
      case CallOutcome.notReachable:  return AppColors.textSecondary;
      case CallOutcome.future:        return AppColors.stageMeeting;
    }
  }

  IconData _outcomeIcon(CallOutcome outcome) {
    switch (outcome) {
      case CallOutcome.interested:    return Icons.thumb_up_outlined;
      case CallOutcome.notInterested: return Icons.thumb_down_outlined;
      case CallOutcome.callback:      return Icons.call_missed_outgoing;
      case CallOutcome.notReachable:  return Icons.phone_missed_outlined;
      case CallOutcome.future:        return Icons.schedule;
    }
  }

  String _futureTagLabel(FutureTag tag) {
    switch (tag) {
      case FutureTag.hot:      return '1 month';
      case FutureTag.warm:     return '3 months';
      case FutureTag.cool:     return '6 months';
      case FutureTag.longTerm: return '1 year+';
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
