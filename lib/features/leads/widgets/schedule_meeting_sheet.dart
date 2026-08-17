import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';

class ScheduleMeetingSheet extends ConsumerStatefulWidget {
  final String leadId;
  final String leadName;
  final String? currentAssignedTo;

  const ScheduleMeetingSheet({
    super.key,
    required this.leadId,
    required this.leadName,
    this.currentAssignedTo,
  });

  @override
  ConsumerState<ScheduleMeetingSheet> createState() => _ScheduleMeetingSheetState();
}

class _ScheduleMeetingSheetState extends ConsumerState<ScheduleMeetingSheet> {
  DateTime? _meetingAt;
  String? _selectedTcId;

  @override
  void initState() {
    super.initState();
    _selectedTcId = widget.currentAssignedTo;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _meetingAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _confirm() {
    if (_meetingAt == null || _selectedTcId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick a meeting time and who\'s managing this client'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    ref.read(leadsProvider.notifier).scheduleMeeting(widget.leadId, _meetingAt!, _selectedTcId!);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Meeting scheduled for ${widget.leadName}'),
        backgroundColor: AppColors.stageMeeting,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final telecallers = ref.watch(telecallersProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.stageMeeting.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_outlined, color: AppColors.stageMeeting, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Schedule Meeting',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(widget.leadName,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Meeting Date & Time',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Text(
                    _meetingAt == null
                        ? 'Select date & time'
                        : DateFormat('EEEE, d MMM · h:mm a').format(_meetingAt!),
                    style: TextStyle(
                      fontSize: 14,
                      color: _meetingAt == null ? AppColors.textSecondary : AppColors.textPrimary,
                      fontWeight: _meetingAt == null ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Managed By',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (telecallers.isEmpty)
            const Text('No telecallers found.', style: TextStyle(color: AppColors.textSecondary))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: telecallers.map((tc) {
                final isSelected = _selectedTcId == tc.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTcId = tc.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.navy.withValues(alpha: 0.08)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.navy : AppColors.divider,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.navy.withValues(alpha: 0.15),
                          child: Text(tc.initials,
                              style: const TextStyle(fontSize: 9, color: AppColors.navy, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          tc.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? AppColors.navy : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.event_available_outlined, size: 16),
                  label: const Text('Confirm Meeting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.stageMeeting,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (_meetingAt == null || _selectedTcId == null) ? null : _confirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
