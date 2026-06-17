import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';

class EditLeadScreen extends ConsumerStatefulWidget {
  final String leadId;
  const EditLeadScreen({super.key, required this.leadId});

  @override
  ConsumerState<EditLeadScreen> createState() => _EditLeadScreenState();
}

class _EditLeadScreenState extends ConsumerState<EditLeadScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _name;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _area;
  late TextEditingController _plotSize;
  late TextEditingController _budget;
  late TextEditingController _notes;

  late LeadSource _source;
  late ServiceType _serviceType;
  late City _city;

  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _area.dispose();
    _plotSize.dispose();
    _budget.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _initFromLead(Lead lead) {
    if (_loaded) return;
    _name     = TextEditingController(text: lead.name);
    _phone    = TextEditingController(text: lead.phone);
    _email    = TextEditingController(text: lead.email ?? '');
    _area     = TextEditingController(text: lead.area ?? '');
    _plotSize = TextEditingController(text: lead.plotSize ?? '');
    _budget   = TextEditingController(text: lead.budget ?? '');
    _notes    = TextEditingController(text: lead.notes ?? '');
    _source      = lead.source;
    _serviceType = lead.serviceType;
    _city        = lead.city;
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final lead = ref.watch(leadByIdProvider(widget.leadId));

    if (lead == null) {
      return const Scaffold(body: Center(child: Text('Lead not found')));
    }

    _initFromLead(lead);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Lead'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(context),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection('Contact Info', [
              _Field(
                controller: _name,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              _Field(
                controller: _phone,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.trim().length < 10 ? 'Enter valid phone' : null,
              ),
              _Field(
                controller: _email,
                label: 'Email (optional)',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Lead Source', [
              _SourceSelector(
                selected: _source,
                onChanged: (s) => setState(() => _source = s),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Service Type', [
              _ToggleGroup<ServiceType>(
                values: ServiceType.values,
                selected: _serviceType,
                label: (s) => s.label,
                onChanged: (s) => setState(() => _serviceType = s),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('City', [
              _ToggleGroup<City>(
                values: City.values,
                selected: _city,
                label: (c) => c.label,
                onChanged: (c) => setState(() => _city = c),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Property Details', [
              _Field(
                controller: _area,
                label: 'Area / Locality',
                icon: Icons.location_on_outlined,
              ),
              _Field(
                controller: _plotSize,
                label: 'Plot Size (e.g. 30×40)',
                icon: Icons.square_foot_outlined,
              ),
              _Field(
                controller: _budget,
                label: 'Budget (e.g. 45–50 Lakhs)',
                icon: Icons.currency_rupee,
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Notes', [
              TextFormField(
                controller: _notes,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Any additional details…',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _save(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Changes',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),
        ...children.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: w,
            )),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final lead = ref.read(leadsProvider.notifier).getById(widget.leadId);
    ref.read(leadsProvider.notifier).updateLead(
          id: widget.leadId,
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          source: _source,
          serviceType: _serviceType,
          city: _city,
          stage: lead?.stage ?? LeadStage.enquiryReceived,
          area: _area.text.trim().isEmpty ? null : _area.text.trim(),
          plotSize: _plotSize.text.trim().isEmpty ? null : _plotSize.text.trim(),
          budget: _budget.text.trim().isEmpty ? null : _budget.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );

    if (context.mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lead updated'),
          backgroundColor: AppColors.navy,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// ─── Reusable field widgets ───────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
        ),
      ),
    );
  }
}

class _SourceSelector extends StatelessWidget {
  final LeadSource selected;
  final void Function(LeadSource) onChanged;

  const _SourceSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: LeadSource.values.map((s) {
        final isSelected = s == selected;
        return GestureDetector(
          onTap: () => onChanged(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.navy : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isSelected ? AppColors.navy : AppColors.divider),
            ),
            child: Text(
              s.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ToggleGroup<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final void Function(T) onChanged;

  const _ToggleGroup({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: values.map((v) {
        final isSelected = v == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(v),
            child: Container(
              margin: EdgeInsets.only(
                  right: v == values.last ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.gold : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        isSelected ? AppColors.gold : AppColors.divider),
              ),
              child: Text(
                label(v),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
