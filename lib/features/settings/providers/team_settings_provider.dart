import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/main.dart';

enum AssignmentStrategy {
  linear,
  reverse,
  performance,
  weighted,
  random,
  manual,
}

extension AssignmentStrategyExt on AssignmentStrategy {
  String get label {
    switch (this) {
      case AssignmentStrategy.linear:      return 'Linear';
      case AssignmentStrategy.reverse:     return 'Reverse';
      case AssignmentStrategy.performance: return 'Performance';
      case AssignmentStrategy.weighted:    return 'Weighted';
      case AssignmentStrategy.random:      return 'Random';
      case AssignmentStrategy.manual:      return 'Manual';
    }
  }

  String get description {
    switch (this) {
      case AssignmentStrategy.linear:
        return 'Equal round-robin — Ravi → Sneha → Divya → Ravi...';
      case AssignmentStrategy.reverse:
        return 'Reverse order — last TC gets leads first';
      case AssignmentStrategy.performance:
        return 'Top scorer this week gets more leads';
      case AssignmentStrategy.weighted:
        return 'Custom percentage split per telecaller';
      case AssignmentStrategy.random:
        return 'Completely random each time';
      case AssignmentStrategy.manual:
        return 'Manager assigns every lead manually';
    }
  }
}

class TeamSettingsNotifier extends StateNotifier<AssignmentStrategy> {
  TeamSettingsNotifier() : super(AssignmentStrategy.linear) {
    _load();
  }

  Future<void> _load() async {
    try {
      // Fetch row — if none exists, create a default one
      final rows = await supabase
          .from('team_settings')
          .select('assignment_strategy')
          .limit(1);

      if ((rows as List).isEmpty) {
        // First time setup — insert default row
        await supabase.from('team_settings')
            .insert({'assignment_strategy': 'linear'});
        return;
      }

      final data = rows.first;
      final str = data['assignment_strategy'] as String? ?? 'linear';
      final strategy = AssignmentStrategy.values.firstWhere(
        (s) => s.name == str,
        orElse: () => AssignmentStrategy.linear,
      );
      if (mounted) state = strategy;
    } catch (_) {}
  }

  Future<void> setStrategy(AssignmentStrategy strategy) async {
    state = strategy;
    try {
      // Upsert — works whether row exists or not
      await supabase.from('team_settings').upsert({
        'assignment_strategy': strategy.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }
}

final teamSettingsProvider =
    StateNotifierProvider<TeamSettingsNotifier, AssignmentStrategy>(
  (ref) => TeamSettingsNotifier(),
);
