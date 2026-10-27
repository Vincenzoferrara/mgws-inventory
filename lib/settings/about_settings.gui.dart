import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../reuse_class/logic/project_links.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';

const _licenseUrl = 'https://www.gnu.org/licenses/gpl-3.0.html';
const _donateUrl = 'https://ko-fi.com/vinc0101';

/// Le build per gli store si compilano con `--dart-define=DONATIONS=false`:
/// Google Play e App Store non accettano link esterni per le donazioni.
const _donationsEnabled = bool.fromEnvironment('DONATIONS', defaultValue: true);

/// Scheda Info: versione, copyright, licenza GPL-3.0, codice sorgente,
/// licenze delle librerie e donazioni.
///
/// Le note legali in questa schermata sono richieste dalla GPL-3.0
/// (sezione 5d) per i programmi con interfaccia interattiva.
class AboutSettingsTab extends StatelessWidget {
  const AboutSettingsTab({super.key});

  bool get _showDonations =>
      _donationsEnabled && defaultTargetPlatform != TargetPlatform.iOS;

  Future<void> _open(BuildContext context, String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.aboutLinkError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return ListView(
      padding: context.spacing.iL,
      children: [
        Row(
          children: [
            Image.asset('assets/images/app_icon.png', width: 56, height: 56),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      if (info == null) return const SizedBox.shrink();
                      return Text(
                        l10n.aboutVersion(info.version, info.buildNumber),
                        style: theme.textTheme.bodySmall,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.aboutCopyright, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        Text(
          l10n.aboutLicenseTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.aboutLicenseBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(l10n.aboutNoWarranty, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(l10n.aboutSourceCode),
                subtitle: const Text(projectSourceUrl),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open(context, projectSourceUrl),
              ),
              ListTile(
                leading: const Icon(Icons.gavel),
                title: Text(l10n.aboutLicenseText),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open(context, _licenseUrl),
              ),
              ListTile(
                leading: const Icon(Icons.extension),
                title: Text(l10n.aboutWordpressPlugin),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open(context, projectPluginUrl),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(l10n.aboutReportIssue),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open(context, projectIssuesUrl),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.aboutOpenSourceLicenses),
                subtitle: Text(l10n.aboutOpenSourceLicensesHelp),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: l10n.appTitle,
                  applicationLegalese: l10n.aboutCopyright,
                ),
              ),
            ],
          ),
        ),
        if (_showDonations) ...[
          const SizedBox(height: 24),
          Text(
            l10n.aboutDonate,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.aboutDonateHelp, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _open(context, _donateUrl),
              icon: const Icon(Icons.favorite),
              label: Text(l10n.aboutDonateButton),
            ),
          ),
        ],
      ],
    );
  }
}
