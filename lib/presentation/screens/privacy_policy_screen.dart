// lib/screens/privacy_policy_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

// 1. Reusable widget for section titles
class _PrivacySectionHeader extends StatelessWidget {
  final String title;

  const _PrivacySectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 5.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// 2. Reusable widget for section body text
class _PrivacySectionBody extends StatelessWidget {
  final String text;

  const _PrivacySectionBody({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 14, height: 1.5));
  }
}

// 3. Main Screen Widget
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocaleProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('privacy_policy'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Text(
              loc.translate('privacy_welcome_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              loc.translate('privacy_welcome_subtitle'),
              style: const TextStyle(fontSize: 16),
            ),

            // Section 1
            _PrivacySectionHeader(
              title: loc.translate('privacy_section1_title'),
            ),
            _PrivacySectionBody(text: loc.translate('privacy_section1_body')),

            // Section 2
            _PrivacySectionHeader(
              title: loc.translate('privacy_section2_title'),
            ),
            _PrivacySectionBody(text: loc.translate('privacy_section2_body')),

            // Section 3
            _PrivacySectionHeader(
              title: loc.translate('privacy_section3_title'),
            ),
            _PrivacySectionBody(text: loc.translate('privacy_section3_body')),

            // Section 4
            _PrivacySectionHeader(
              title: loc.translate('privacy_section4_title'),
            ),
            _PrivacySectionBody(text: loc.translate('privacy_section4_body')),

            // Section 5
            _PrivacySectionHeader(
              title: loc.translate('privacy_section5_title'),
            ),
            _PrivacySectionBody(text: loc.translate('privacy_section5_body')),

            // Footer
            const SizedBox(height: 30),
            Text(
              loc.translate('privacy_last_updated'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
