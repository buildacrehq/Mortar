import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';

class AddLeadScreen extends ConsumerStatefulWidget {
  const AddLeadScreen({super.key});

  @override
  ConsumerState<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends ConsumerState<AddLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _areaController = TextEditingController();
  final _plotController = TextEditingController();
  final _budgetController = TextEditingController();
  final _notesController = TextEditingController();

  LeadSource _source = LeadSource.phone;
  ServiceType _serviceType = ServiceType.construction;
  City _city = City.bangalore;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _areaController.dispose();
    _plotController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    ref.read(leadsProvider.notifier).addLead(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          source: _source,
          serviceType: _serviceType,
          city: _city,
          area: _areaController.text.trim().isEmpty
              ? null
              : _areaController.text.trim(),
          plotSize: _plotController.text.trim().isEmpty
              ? null
              : _plotController.text.trim(),
          budget: _budgetController.text.trim().isEmpty
              ? null
              : _budgetController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Lead'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(label: 'Contact Info'),
            const SizedBox(height: 10),
            _buildField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline,
              inputAction: TextInputAction.next,
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone is required';
                if (v.trim().length < 10) return 'Enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _emailController,
              label: 'Email (optional)',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              inputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            _SectionHeader(label: 'Lead Details'),
            const SizedBox(height: 10),
            _buildSourceSelector(),
            const SizedBox(height: 12),
            _buildServiceTypeSelector(),
            const SizedBox(height: 12),
            _buildCitySelector(),
            const SizedBox(height: 20),
            _SectionHeader(label: 'Property Info'),
            const SizedBox(height: 10),
            _buildField(
              controller: _areaController,
              label: 'Area / Locality (optional)',
              icon: Icons.location_on_outlined,
              inputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _plotController,
                    label: 'Plot Size (optional)',
                    icon: Icons.square_foot,
                    hint: 'e.g. 30x40',
                    inputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    controller: _budgetController,
                    label: 'Budget (optional)',
                    icon: Icons.currency_rupee,
                    hint: 'e.g. 40-50 Lakhs',
                    inputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionHeader(label: 'Notes'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Client requirements, budget details, anything important…',
                hintStyle: Theme.of(context).textTheme.bodyMedium,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add Lead'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    TextInputAction? inputAction,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: inputAction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(text: 'Lead Source'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LeadSource.values.map((s) {
            final selected = _source == s;
            return GestureDetector(
              onTap: () => setState(() => _source = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppColors.navy : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? AppColors.navy : AppColors.divider,
                  ),
                ),
                child: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildServiceTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(text: 'Service Type'),
        const SizedBox(height: 8),
        Row(
          children: ServiceType.values.map((s) {
            final selected = _serviceType == s;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: s != ServiceType.values.last ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _serviceType = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.navy : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? AppColors.navy : AppColors.divider,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
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

  Widget _buildCitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(text: 'City'),
        const SizedBox(height: 8),
        Row(
          children: City.values.map((c) {
            final selected = _city == c;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: c != City.values.last ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _city = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.gold : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? AppColors.gold : AppColors.divider,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
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
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    );
  }
}
