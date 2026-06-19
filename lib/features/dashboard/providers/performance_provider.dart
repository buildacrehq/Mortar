import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';
import 'package:buildacre_crm/features/dashboard/models/telecaller_stats.dart';
import 'package:buildacre_crm/features/dashboard/providers/analytics_provider.dart';

final telecallerStatsProvider = Provider<List<TelecallerStats>>((ref) {
  final analytics = ref.watch(analyticsProvider);
  final telecallers = ref.watch(telecallersProvider);
  // Uses full analytics data — not affected by pagination
  return telecallers
      .map((tc) => computeStatsFromAnalytics(tc, analytics.leads, analytics.callLogs))
      .toList()
    ..sort((a, b) => b.performanceScore.compareTo(a.performanceScore));
});
