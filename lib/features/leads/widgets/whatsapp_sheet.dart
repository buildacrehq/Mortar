import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';

// ─── Templates ────────────────────────────────────────────────────────────────

class _WaTemplate {
  final String title;
  final String emoji;
  final String Function(Lead) body;
  const _WaTemplate({required this.title, required this.emoji, required this.body});
}

final _templates = [
  _WaTemplate(
    title: 'Initial Response',
    emoji: '👋',
    body: (l) =>
        'Hello ${l.name}! 🙏\n\n'
        'Thank you for your interest in Buildacre. We specialize in turnkey ${l.serviceType.label.toLowerCase()} projects in ${l.city.label}.\n\n'
        'I\'d love to understand your requirements better. Could we set up a quick call at your convenience?\n\n'
        'Warm regards,\nBuildacre Team',
  ),
  _WaTemplate(
    title: 'Meeting Confirmation',
    emoji: '📅',
    body: (l) =>
        'Hello ${l.name}! 🙏\n\n'
        'This is a confirmation for your meeting at the Buildacre office.\n\n'
        '📍 Buildacre Office, ${l.city.label}\n'
        '⏰ Please confirm your preferred date & time.\n\n'
        'We look forward to meeting you and discussing your ${l.serviceType.label.toLowerCase()} project!\n\n'
        'Buildacre Team',
  ),
  _WaTemplate(
    title: 'Quotation Follow-up',
    emoji: '📋',
    body: (l) =>
        'Hello ${l.name}! 🙏\n\n'
        'We hope you had a chance to review the quotation we sent for your ${l.serviceType.label.toLowerCase()} project'
        '${l.area != null ? ' in ${l.area}' : ''}.\n\n'
        'We\'re happy to discuss any questions or adjustments. Our team is here to ensure the project fits your budget and timeline.\n\n'
        'Shall we schedule a quick call to take this forward? 📞\n\n'
        'Buildacre Team',
  ),
  _WaTemplate(
    title: 'Site Visit Reminder',
    emoji: '🏗️',
    body: (l) =>
        'Hello ${l.name}! 🙏\n\n'
        'Just a reminder about your upcoming site visit'
        '${l.area != null ? ' at ${l.area}' : ''}.\n\n'
        'Our engineer will walk you through the plot assessment and project plan.\n\n'
        'Please let us know if you need to reschedule. 🙂\n\n'
        'Buildacre Team',
  ),
  _WaTemplate(
    title: 'Follow-up Check-in',
    emoji: '🤝',
    body: (l) =>
        'Hello ${l.name}! 🙏\n\n'
        'Just checking in to see if you\'re still considering the ${l.serviceType.label.toLowerCase()} project'
        '${l.budget != null ? ' (${l.budget})' : ''}.\n\n'
        'We\'d love to help you move forward. No pressure — just here if you have any questions!\n\n'
        'Buildacre Team',
  ),
];

// ─── Sheet ────────────────────────────────────────────────────────────────────

class WhatsAppSheet extends StatefulWidget {
  final Lead lead;
  const WhatsAppSheet({super.key, required this.lead});

  @override
  State<WhatsAppSheet> createState() => _WhatsAppSheetState();
}

class _WhatsAppSheetState extends State<WhatsAppSheet> {
  int _selected = 0;
  late TextEditingController _msgController;

  @override
  void initState() {
    super.initState();
    _msgController = TextEditingController(
        text: _templates[_selected].body(widget.lead));
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  void _selectTemplate(int i) {
    setState(() {
      _selected = i;
      _msgController.text = _templates[i].body(widget.lead);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WhatsApp',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(
                      widget.lead.name,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Template chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _templates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _templates[i];
                final isSelected = _selected == i;
                return GestureDetector(
                  onTap: () => _selectTemplate(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF25D366)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          t.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Message editor
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _msgController,
                maxLines: 6,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration.collapsed(
                  hintText: 'Edit message…',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              children: [
                // Copy button
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _msgController.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message copied'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Open WhatsApp button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Open WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openWhatsApp(context),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    // Strip non-digits, add country code if missing
    var phone = widget.lead.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.length == 10) phone = '91$phone'; // India default

    final encoded = Uri.encodeComponent(_msgController.text);
    final waUrl = Uri.parse('whatsapp://send?phone=$phone&text=$encoded');
    final webUrl = Uri.parse('https://wa.me/$phone?text=$encoded');

    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl);
    } else {
      // Fallback to web if WhatsApp not installed (simulator)
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) Navigator.pop(context);
  }
}
