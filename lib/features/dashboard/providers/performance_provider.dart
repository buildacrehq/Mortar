import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';
import 'package:buildacre_crm/features/dashboard/models/telecaller_stats.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';

final telecallerStatsProvider = Provider<List<TelecallerStats>>((ref) {
  final leads = ref.watch(leadsProvider);
  final telecallers = ref.watch(telecallersProvider);
  return telecallers
      .map((tc) => computeStats(tc, leads))
      .toList()
    ..sort((a, b) => b.performanceScore.compareTo(a.performanceScore));
});
