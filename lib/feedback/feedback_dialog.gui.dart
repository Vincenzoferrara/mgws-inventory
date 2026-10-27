import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/extensions.dart';
import '../reuse_class/logic/project_links.dart';
import '../theme/theme.dart';
import 'feedback_report.dart';
import 'feedback_sanitizer.dart';
import 'feedback_sender.dart';

/// Apre il modulo di feedback: a schermo intero su smartphone, dialog sul
/// desktop, come il login della home.
Future<void> showFeedbackDialog(
  BuildContext context, {
  required bool fullScreen,
  required FeedbackTechInfo techInfo,
  required FeedbackSanitizer sanitizer,
}) {
  final form = FeedbackForm(techInfo: techInfo, sanitizer: sanitizer);
  if (fullScreen) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(context.l10n.feedbackTitolo)),
          body: SafeArea(child: form),
        ),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.feedbackTitolo,
                      style: context.text.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(child: form),
          ],
        ),
      ),
    ),
  );
}

/// Modulo in due passi: compilazione, poi anteprima del testo pubblico.
///
/// L'anteprima e' obbligatoria: il repository e' pubblico e l'utente deve
/// vedere esattamente cosa esce dall'app prima di aprire GitHub.
class FeedbackForm extends StatefulWidget {
  const FeedbackForm({
    super.key,
    required this.techInfo,
    required this.sanitizer,
    this.sender = const GithubUrlFeedbackSender(),
  });

  final FeedbackTechInfo techInfo;
  final FeedbackSanitizer sanitizer;
  final FeedbackSender sender;

  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _previewController = TextEditingController();

  FeedbackKind _kind = FeedbackKind.bug;
  bool _attachLogs = false;
  bool _showPreview = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  String get _sanitizedTitle =>
      widget.sanitizer.sanitize(_titleController.text.trim());

  void _openPreview() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final report = FeedbackReport(
      kind: _kind,
      title: _sanitizedTitle,
      description: widget.sanitizer.sanitize(_descriptionController.text),
      techInfo: widget.techInfo,
      logLines: _attachLogs
          ? FeedbackReport.recentProblemLogs(widget.sanitizer)
          : const [],
    );
    _previewController.text = report.toMarkdown(
      fits: (body) => GithubUrlFeedbackSender.fits(
        kind: _kind,
        title: report.title,
        body: body,
      ),
    );
    setState(() => _showPreview = true);
  }

  /// Il testo dell'anteprima e' modificabile: lo si ripulisce di nuovo nel
  /// caso l'utente vi abbia aggiunto un dato sensibile.
  String get _finalBody => widget.sanitizer.sanitize(_previewController.text);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _finalBody));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.feedbackCopiato)));
  }

  Future<void> _send() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    bool opened;
    try {
      opened = await widget.sender.send(
        kind: _kind,
        title: _sanitizedTitle,
        body: _finalBody,
      );
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (!opened) {
      // Il testo resta nel modulo: l'utente puo' copiarlo e incollarlo.
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(l10n.feedbackBrowserErrore(projectIssuesUrl)),
        ),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.feedbackGithubAperto)));
  }

  Future<void> _openSecurityAdvisory() async {
    await launchUrl(
      Uri.parse(projectSecurityAdvisoryUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: _showPreview ? _buildPreview(context) : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PublicNotice(text: l10n.feedbackAvvisoPubblico),
                  const SizedBox(height: 16),
                  SegmentedButton<FeedbackKind>(
                    segments: [
                      ButtonSegment(
                        value: FeedbackKind.bug,
                        icon: const Icon(Icons.bug_report_outlined),
                        label: Text(l10n.feedbackTipoBug),
                      ),
                      ButtonSegment(
                        value: FeedbackKind.idea,
                        icon: const Icon(Icons.lightbulb_outline),
                        label: Text(l10n.feedbackTipoIdea),
                      ),
                      ButtonSegment(
                        value: FeedbackKind.question,
                        icon: const Icon(Icons.help_outline),
                        label: Text(l10n.feedbackTipoDomanda),
                      ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (selection) =>
                        setState(() => _kind = selection.first),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: l10n.feedbackCampoTitolo,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? l10n.feedbackTitoloObbligatorio
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 4,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: l10n.feedbackCampoDescrizione,
                      // I manutentori leggono solo italiano e inglese.
                      helperText: l10n.feedbackLingue,
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _attachLogs,
                    onChanged: (value) =>
                        setState(() => _attachLogs = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.feedbackAllegaLog),
                    subtitle: Text(l10n.feedbackAllegaLogDettaglio),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openSecurityAdvisory,
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: Text(l10n.feedbackSicurezza),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _openPreview,
              icon: const Icon(Icons.visibility_outlined),
              label: Text(l10n.feedbackAnteprima),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.feedbackAnteprimaSpiegazione, style: context.text.bodyMedium),
        const SizedBox(height: 8),
        Text(_sanitizedTitle, style: context.text.titleMedium),
        const SizedBox(height: 8),
        Flexible(
          child: TextField(
            controller: _previewController,
            minLines: 8,
            maxLines: null,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: () => setState(() => _showPreview = false),
              child: Text(l10n.feedbackIndietro),
            ),
            OutlinedButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l10n.feedbackCopia),
            ),
            FilledButton.icon(
              onPressed: _send,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.feedbackApriGithub),
            ),
          ],
        ),
      ],
    );
  }
}

class _PublicNotice extends StatelessWidget {
  const _PublicNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final warning = context.colors.warningColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.1),
        border: Border.all(color: warning.withValues(alpha: 0.3)),
        borderRadius: context.shapes.s,
      ),
      child: Row(
        children: [
          Icon(Icons.public, color: warning, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
