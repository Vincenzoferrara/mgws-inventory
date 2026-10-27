import 'package:url_launcher/url_launcher.dart';

import '../reuse_class/logic/project_links.dart';
import 'feedback_report.dart';

/// Strada con cui il feedback arriva su GitHub.
///
/// Oggi c'e' solo [GithubUrlFeedbackSender]; un invio tramite proxy potra'
/// implementare la stessa interfaccia senza toccare la schermata.
abstract class FeedbackSender {
  /// Restituisce `false` se l'invio non e' partito.
  Future<bool> send({
    required FeedbackKind kind,
    required String title,
    required String body,
  });
}

/// Apre nel browser la pagina "nuova issue" gia' compilata.
///
/// Nessun token nell'app: la issue la crea l'utente con il proprio account
/// GitHub premendo "Submit". Il template `app_feedback.md` aggiunge da solo
/// l'etichetta `from-app`.
class GithubUrlFeedbackSender implements FeedbackSender {
  const GithubUrlFeedbackSender();

  /// GitHub rifiuta gli URL troppo lunghi; restiamo sotto con margine.
  static const maxUrlLength = 7500;
  static const _template = 'app_feedback.md';
  static const _truncatedNote = '\n\n… (text truncated)';

  static Uri issueUri({
    required FeedbackKind kind,
    required String title,
    required String body,
  }) {
    final base = Uri.parse('$projectIssuesUrl/new');
    return base.replace(
      queryParameters: {
        'template': _template,
        'title': title.trim(),
        'labels': kind.githubLabel,
        'body': body,
      },
    );
  }

  static bool fits({
    required FeedbackKind kind,
    required String title,
    required String body,
  }) =>
      issueUri(kind: kind, title: title, body: body).toString().length <=
      maxUrlLength;

  /// URL finale, accorciando il testo se anche senza log resta troppo lungo.
  static Uri fittedIssueUri({
    required FeedbackKind kind,
    required String title,
    required String body,
  }) {
    var text = body;
    while (!fits(kind: kind, title: title, body: text) && text.length > 200) {
      final cut = (text.length * 0.9).floor();
      text =
          text.substring(0, cut).replaceAll(_truncatedNote, '') +
          _truncatedNote;
    }
    return issueUri(kind: kind, title: title, body: text);
  }

  @override
  Future<bool> send({
    required FeedbackKind kind,
    required String title,
    required String body,
  }) {
    return launchUrl(
      fittedIssueUri(kind: kind, title: title, body: body),
      mode: LaunchMode.externalApplication,
    );
  }
}
