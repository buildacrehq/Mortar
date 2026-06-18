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
      final data = await supabase
          .from('team_settings')
          .select('assignment_strategy')
          .single();
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
      await supabase
          .from('team_settings')
          .update({'assignment_strategy': strategy.name, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', await _getSettingsId());
    } catch (_) {}
  }

  Future<String> _getSettingsId() async {
    final data = await supabase.from('team_settings').select('id').single();
    return data['id'] as String;
  }
}

final teamSettingsProvider =
    StateNotifierProvider<TeamSettingsNotifier, AssignmentStrategy>(
  (ref) => TeamSettingsNotifier(),
);
