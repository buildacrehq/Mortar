import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/auth/providers/auth_provider.dart';
import 'package:buildacre_crm/features/auth/providers/profiles_provider.dart';
import 'package:buildacre_crm/main.dart';

class InviteMemberScreen extends ConsumerStatefulWidget {
  const InviteMemberScreen({super.key});

  @override
  ConsumerState<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends ConsumerState<InviteMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  UserRole _role = UserRole.telecaller;
  City _city = City.bangalore;
  bool _loading = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final session = supabase.auth.currentSession;
      final jwt = session?.accessToken ?? '';

      final response = await http.post(
        Uri.parse('${AppConstants.backendUrl}/team/create-member'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim().toLowerCase(),
          'phone': _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'role': _role.name,
          'city': _city.name,
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      if (response.statusCode == 200) {
        ref.read(profilesProvider.notifier).refresh();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_nameCtrl.text.trim()} added successfully'),
          backgroundColor: AppColors.stageWon,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      } else {
        final msg = body['error'] as String? ?? 'Failed to create member';
        _showError(msg);
      }
    } catch (e) {
      _showError('Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Team Member'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold),
                  )
                : const Text('Save', style: TextStyle(color: AppColors.gold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Role selector
            _SectionLabel('ROLE'),
            const SizedBox(height: 8),
            Row(
              children: UserRole.values.map((r) {
                final isSelected = _role == r;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _role = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppColors.navy : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.navy
                              : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        _roleLabel(r),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Name
            _SectionLabel('FULL NAME'),
            const SizedBox(height: 8),
            _Field(
              controller: _nameCtrl,
              hint: 'e.g. Ravi Kumar',
              icon: Icons.person_outline,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            // Email
            _SectionLabel('EMAIL'),
            const SizedBox(height: 8),
            _Field(
              controller: _emailCtrl,
              hint: 'ravi@buildacre.in',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone
            _SectionLabel('PHONE (OPTIONAL)'),
            const SizedBox(height: 8),
            _Field(
              controller: _phoneCtrl,
              hint: '9876543210',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // City
            _SectionLabel('CITY'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: DropdownButtonFormField<City>(
                value: _city,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined,
                      size: 20, color: AppColors.navy),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                items: City.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.label),
                        ))
                    .toList(),
                onChanged: (c) {
                  if (c != null) setState(() => _city = c);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Password
            _SectionLabel('INITIAL PASSWORD'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePass,
              decoration: InputDecoration(
                hintText: 'Minimum 8 characters',
                prefixIcon: const Icon(Icons.lock_outline,
                    size: 20, color: AppColors.navy),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
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
                  borderSide: const BorderSide(color: AppColors.navy),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8) return 'Minimum 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Share this password with the team member. They can change it from Settings → Change Password.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Team Member',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(UserRole r) {
    switch (r) {
      case UserRole.telecaller:
        return 'Telecaller';
      case UserRole.manager:
        return 'Manager';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.navy),
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
          borderSide: const BorderSide(color: AppColors.navy),
        ),
      ),
      validator: validator,
    );
  }
}
