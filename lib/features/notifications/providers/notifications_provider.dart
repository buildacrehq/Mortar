import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/notifications/models/app_notification.dart';
import 'package:buildacre_crm/features/dashboard/models/telecaller_stats.dart';

// Tracks which notification IDs have been read
final _readIdsProvider = StateProvider<Set<String>>((ref) => {});

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  NotificationsNotifier(this._ref) : super([]);
  final Ref _ref;

  List<AppNotification> buildNotifications() {
    final leads = _ref.read(leadsProvider);
    final user = _ref.read(authProvider);
    final role = _ref.read(currentUserRoleProvider);
    final readIds = _ref.read(_readIdsProvider);
    final tcMap = {for (final t in mockTelecallers) t.id: t};
    final now = DateTime.now();

    final notifs = <AppNotification>[];

    if (role == UserRole.telecaller) {
      // My overdue follow-ups
      final myOverdue = leads.where((l) =>
          l.assignedTo == user?.id && l.hasOverdueFollowup);
      for (final lead in myOverdue) {
        final daysAgo =
            now.difference(lead.followupAt!).inDays;
        notifs.add(AppNotification(
          id: 'overdue_${lead.id}',
          type: NotificationType.alert,
          title: 'Overdue follow-up',
          body: '${lead.name} — due ${daysAgo == 0 ? "today" : "${daysAgo}d ago"}',
          createdAt: lead.followupAt!,
          leadId: lead.id,
          isRead: readIds.contains('overdue_${lead.id}'),
        ));
      }

      // New leads assigned to me in last 48h
      final recentAssigned = leads.where((l) =>
          l.assignedTo == user?.id &&
          now.difference(l.createdAt).inHours <= 48 &&
          l.callLogs.isEmpty);
      for (final lead in recentAssigned) {
        notifs.add(AppNotification(
          id: 'assigned_${lead.id}',
          type: NotificationType.assignment,
          title: 'New lead assigned',
          body: '${lead.name} · ${lead.serviceType.label} · ${lead.city.label}',
          createdAt: lead.createdAt,
          leadId: lead.id,
          isRead: readIds.contains('assigned_${lead.id}'),
        ));
      }
    } else {
      // Manager / Admin

      // Short calls flagged (< 30s)
      for (final lead in leads) {
        final tc = tcMap[lead.assignedTo];
        for (final log in lead.callLogs) {
          if (log.isSuspiciouslyShort) {
            notifs.add(AppNotification(
              id: 'shortcall_${log.id}',
              type: NotificationType.callQuality,
              title: 'Short call flagged',
              body: '${tc?.name ?? "TC"} · ${lead.name} · ${log.durationSeconds}s',
              createdAt: log.calledAt,
              leadId: lead.id,
              isRead: readIds.contains('shortcall_${log.id}'),
            ));
          }
        }
      }

      // Overdue leads across all TCs (limit to 5 most overdue)
      final allOverdue = leads
          .where((l) => l.hasOverdueFollowup)
          .toList()
        ..sort((a, b) => a.followupAt!.compareTo(b.followupAt!));
      for (final lead in allOverdue.take(5)) {
        final tc = tcMap[lead.assignedTo];
        final daysAgo = now.difference(lead.followupAt!).inDays;
        notifs.add(AppNotification(
          id: 'mgr_overdue_${lead.id}',
          type: NotificationType.alert,
          title: 'Overdue follow-up',
          body: '${tc?.name.split(" ").first ?? "TC"} · ${lead.name} · $daysAgo d overdue',
          createdAt: lead.followupAt!,
          leadId: lead.id,
          isRead: readIds.contains('mgr_overdue_${lead.id}'),
        ));
      }

      // Stage updates: leads that moved to finalAgreement or negotiation recently
      final stageLeads = leads.where((l) =>
          l.stage == LeadStage.finalAgreement ||
          l.stage == LeadStage.negotiation);
      for (final lead in stageLeads) {
        if (lead.lastContactedAt != null &&
            now.difference(lead.lastContactedAt!).inDays <= 3) {
          final tc = tcMap[lead.assignedTo];
          notifs.add(AppNotification(
            id: 'stage_${lead.id}_${lead.stage.name}',
            type: NotificationType.stageUpdate,
            title: lead.stage == LeadStage.finalAgreement
                ? 'Deal won!'
                : 'Entered negotiation',
            body: '${tc?.name.split(" ").first ?? "TC"} · ${lead.name} · ${lead.serviceType.label}',
            createdAt: lead.lastContactedAt!,
            leadId: lead.id,
            isRead: readIds.contains('stage_${lead.id}_${lead.stage.name}'),
          ));
        }
      }

      // Future leads due within 7 days
      final futureDue = leads.where((l) {
        if (l.futureTag == null || l.followupAt == null) return false;
        final diff = l.followupAt!.difference(now).inDays;
        return diff >= 0 && diff <= 7;
      });
      for (final lead in futureDue) {
        final tc = tcMap[lead.assignedTo];
        final diff = lead.followupAt!.difference(now).inDays;
        notifs.add(AppNotification(
          id: 'futuredue_${lead.id}',
          type: NotificationType.futureDue,
          title: 'Future lead due soon',
          body:
              '${lead.name} · ${lead.futureTag!.label} · ${diff == 0 ? "today" : "in $diff days"}',
          createdAt: lead.followupAt!.subtract(const Duration(days: 1)),
          leadId: lead.id,
          isRead: readIds.contains('futuredue_${lead.id}'),
        ));
      }

      // New leads in last 24h without assignment
      final unassigned = leads.where((l) =>
          (l.assignedTo == null || l.assignedTo!.isEmpty) &&
          now.difference(l.createdAt).inHours <= 24);
      for (final lead in unassigned) {
        notifs.add(AppNotification(
          id: 'unassigned_${lead.id}',
          type: NotificationType.assignment,
          title: 'Unassigned lead',
          body: '${lead.name} · ${lead.source.label} · ${lead.serviceType.label}',
          createdAt: lead.createdAt,
          leadId: lead.id,
          isRead: readIds.contains('unassigned_${lead.id}'),
        ));
      }
    }

    // Sort: unread first, then by recency
    notifs.sort((a, b) {
      if (a.isRead != b.isRead) return a.isRead ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });

    return notifs;
  }

  void markRead(String id) {
    _ref.read(_readIdsProvider.notifier).update((s) => {...s, id});
  }

  void markAllRead(List<String> ids) {
    _ref.read(_readIdsProvider.notifier).update((s) => {...s, ...ids});
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  (ref) => NotificationsNotifier(ref),
);

// Derived: unread count — watches leads + readIds to stay reactive
final unreadCountProvider = Provider<int>((ref) {
  ref.watch(leadsProvider);
  ref.watch(authProvider);
  ref.watch(currentUserRoleProvider);
  ref.watch(_readIdsProvider);

  final all = ref.read(notificationsProvider.notifier).buildNotifications();
  return all.where((n) => !n.isRead).length;
});
