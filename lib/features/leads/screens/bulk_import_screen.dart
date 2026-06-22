import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';

class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});

  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  final _controller = TextEditingController();
  LeadSource _source = LeadSource.facebook;
  ServiceType _serviceType = ServiceType.construction;
  City _city = City.bangalore;

  bool _importing = false;
  List<_ParsedLead> _parsed = [];
  int _imported = 0;
  int _duplicates = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    final lines = _controller.text.trim().split('\n');
    final leads = <_ParsedLead>[];
    final existing = ref.read(leadsProvider);
    final existingPhones = existing.map((l) => l.phone.replaceAll(RegExp(r'\D'), '')).toSet();

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      // Support: "Name, Phone" or "Phone, Name" or just "Phone"
      final parts = line.split(RegExp(r'[,\t]')).map((p) => p.trim()).toList();

      String name = '';
      String phone = '';

      if (parts.length >= 2) {
        // Figure out which is name and which is phone
        final first = parts[0].replaceAll(RegExp(r'\D'), '');
        if (first.length >= 10) {
          phone = first;
          name = parts[1];
        } else {
          name = parts[0];
          phone = parts[1].replaceAll(RegExp(r'\D'), '');
        }
      } else {
        phone = parts[0].replaceAll(RegExp(r'\D'), '');
      }

      if (phone.length < 10) continue;
      if (phone.length > 10) phone = phone.substring(phone.length - 10);

      final isDuplicate = existingPhones.contains(phone);
      leads.add(_ParsedLead(
        name: name.isEmpty ? 'Lead $phone' : name,
        phone: phone,
        isDuplicate: isDuplicate,
      ));
    }

    setState(() => _parsed = leads);
  }

  Future<void> _import() async {
    if (_parsed.isEmpty) return;
    setState(() { _importing = true; _imported = 0; _duplicates = 0; });

    final user = ref.read(authProvider);
    final toImport = _parsed.where((l) => !l.isDuplicate).toList();

    for (final lead in toImport) {
      await ref.read(leadsProvider.notifier).addLead(
        name: lead.name,
        phone: lead.phone,
        source: _source,
        serviceType: _serviceType,
        city: _city,
        assignedTo: user?.id,
      );
      setState(() => _imported++);
      // Small delay to avoid overwhelming Supabase
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setState(() {
      _importing = false;
      _duplicates = _parsed.where((l) => l.isDuplicate).length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _parsed.where((l) => !l.isDuplicate).length;
    final dupCount = _parsed.where((l) => l.isDuplicate).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Import Leads')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paste from Google Sheets',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                SizedBox(height: 6),
                Text(
                  'Copy rows from your Sheets and paste below.\n'
                  'Supported formats:\n'
                  '  • Name, Phone\n'
                  '  • Phone, Name\n'
                  '  • Phone only',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Paste area
          TextField(
            controller: _controller,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: 'Paste leads here...\n\nExample:\nRajesh Kumar, 9876543210\nPriya Sharma, 8765432109',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
            onChanged: (_) => setState(() => _parsed = []),
          ),
          const SizedBox(height: 12),

          // Parse button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.find_in_page_outlined, size: 18),
              label: const Text('Preview Leads'),
              onPressed: _controller.text.trim().isEmpty ? null : _parse,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                side: const BorderSide(color: AppColors.navy),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          if (_parsed.isNotEmpty) ...[
            const SizedBox(height: 20),

            // Source + Service + City selectors
            _buildSelector('Source', LeadSource.values.map((s) => s.label).toList(),
                LeadSource.values.indexOf(_source),
                (i) => setState(() => _source = LeadSource.values[i])),
            const SizedBox(height: 10),
            _buildSelector('Service', ServiceType.values.map((s) => s.label).toList(),
                ServiceType.values.indexOf(_serviceType),
                (i) => setState(() => _serviceType = ServiceType.values[i])),
            const SizedBox(height: 10),
            _buildSelector('City', City.values.map((c) => c.label).toList(),
                City.values.indexOf(_city),
                (i) => setState(() => _city = City.values[i])),
            const SizedBox(height: 16),

            // Summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_parsed.length} leads parsed',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _SummaryChip('$validCount to import', AppColors.stageWon),
                    const SizedBox(width: 8),
                    if (dupCount > 0)
                      _SummaryChip('$dupCount duplicates', Colors.orangeAccent),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Preview list
            ...(_parsed.take(20).map((l) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: l.isDuplicate ? Colors.orangeAccent.withValues(alpha: 0.06) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: l.isDuplicate ? Colors.orangeAccent.withValues(alpha: 0.4) : AppColors.divider,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    l.isDuplicate ? Icons.warning_amber_outlined : Icons.person_outline,
                    size: 16,
                    color: l.isDuplicate ? Colors.orangeAccent : AppColors.navy,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(l.phone,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (l.isDuplicate)
                    const Text('Exists', style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                ],
              ),
            ))),

            if (_parsed.length > 20)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('+${_parsed.length - 20} more...',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),

            const SizedBox(height: 16),

            // Import button
            if (!_importing && _imported == 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.upload_outlined, size: 18),
                  label: Text('Import $validCount Lead${validCount != 1 ? 's' : ''}'),
                  onPressed: validCount == 0 ? null : _import,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

            if (_importing)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: toImport.isEmpty ? null : _imported / toImport.length,
                    color: AppColors.gold,
                    backgroundColor: AppColors.surface,
                  ),
                  const SizedBox(height: 8),
                  Text('Importing $_imported of ${validCount}...',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),

            if (!_importing && _imported > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.stageWon.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.stageWon.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.stageWon, size: 32),
                    const SizedBox(height: 8),
                    Text('$_imported lead${_imported != 1 ? 's' : ''} imported successfully!',
                        style: const TextStyle(
                            color: AppColors.stageWon, fontWeight: FontWeight.w700, fontSize: 15)),
                    if (_duplicates > 0) ...[
                      const SizedBox(height: 4),
                      Text('$_duplicates duplicate${_duplicates != 1 ? 's' : ''} skipped',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<_ParsedLead> get toImport => _parsed.where((l) => !l.isDuplicate).toList();

  Widget _buildSelector(String label, List<String> options, int selected, void Function(int) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(
          children: options.indexed.map((e) {
            final isSelected = e.$1 == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(e.$1),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.navy : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? AppColors.navy : AppColors.divider),
                  ),
                  child: Text(e.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ParsedLead {
  final String name;
  final String phone;
  final bool isDuplicate;
  const _ParsedLead({required this.name, required this.phone, required this.isDuplicate});
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
