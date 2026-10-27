import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../log_viewer/app_logger.dart';
import 'feedback_sanitizer.dart';

/// Tipo di segnalazione, ognuno con l'etichetta GitHub che gli corrisponde.
enum FeedbackKind {
  bug('bug'),
  idea('enhancement'),
  question('question');

  const FeedbackKind(this.githubLabel);

  final String githubLabel;
}

/// Informazioni tecniche allegate a ogni feedback.
///
/// E' un elenco chiuso di proposito: un campo nuovo va aggiunto qui a mano,
/// cosi' nessun dato del negozio finisce nella issue pubblica per sbaglio.
/// Niente dominio, nome utente o identificativi del dispositivo.
@immutable
class FeedbackTechInfo {
  const FeedbackTechInfo({
    required this.appVersion,
    required this.platform,
    required this.locale,
    required this.connected,
    required this.mgwsAvailable,
    this.mgwsVersion,
  });

  final String appVersion;
  final String platform;
  final String locale;
  final bool connected;
  final bool mgwsAvailable;
  final String? mgwsVersion;

  static Future<FeedbackTechInfo> collect({
    required String locale,
    required bool connected,
    required bool mgwsAvailable,
    String? mgwsVersion,
  }) async {
    var appVersion = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version} (build ${info.buildNumber})';
    } catch (_) {
      // Senza versione il feedback resta utile: si invia comunque.
    }
    return FeedbackTechInfo(
      appVersion: appVersion,
      platform: _platformLabel(),
      locale: locale,
      connected: connected,
      mgwsAvailable: mgwsAvailable,
      mgwsVersion: mgwsVersion,
    );
  }

  /// Solo sistema e versione: niente nome del computer o modello esatto.
  static String _platformLabel() {
    if (kIsWeb) return 'web';
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }
}

/// Feedback pronto da trasformare nel testo della issue.
class FeedbackReport {
  FeedbackReport({
    required this.kind,
    required this.title,
    required this.description,
    required this.techInfo,
    this.logLines = const [],
  });

  /// Righe di log al massimo allegate: bastano per capire l'ultimo errore.
  static const maxLogLines = 50;
  static const _maxLogLineLength = 300;

  final FeedbackKind kind;
  final String title;
  final String description;
  final FeedbackTechInfo techInfo;
  final List<String> logLines;

  /// Ultimi avvisi ed errori in memoria, gia' passati da [sanitizer].
  static List<String> recentProblemLogs(FeedbackSanitizer sanitizer) {
    final problems = AppLogger().memoryEvents
        .where((event) => event.severity.index >= AppLogSeverity.warning.index)
        .toList();
    final recent = problems.length > maxLogLines
        ? problems.sublist(problems.length - maxLogLines)
        : problems;
    return recent.map((event) {
      final line = sanitizer.sanitize(event.formatted);
      return line.length > _maxLogLineLength
          ? '${line.substring(0, _maxLogLineLength)}…'
          : line;
    }).toList();
  }

  /// Testo Markdown della issue, in inglese come i template del repository.
  ///
  /// Se [fits] rifiuta il testo, toglie le righe di log piu' vecchie finche'
  /// non entra: l'URL di GitHub ha una lunghezza massima.
  String toMarkdown({bool Function(String body)? fits}) {
    var lines = logLines;
    var body = _build(lines);
    while (fits != null && !fits(body) && lines.isNotEmpty) {
      lines = lines.sublist(1);
      body = _build(lines, truncated: true);
    }
    return body;
  }

  String _build(List<String> lines, {bool truncated = false}) {
    final mgws = techInfo.mgwsAvailable
        ? 'yes${techInfo.mgwsVersion == null ? '' : ' (${techInfo.mgwsVersion})'}'
        : 'no';
    final buffer = StringBuffer()
      ..writeln('### Description')
      ..writeln()
      ..writeln(
        description.trim().isEmpty ? '_No description._' : description.trim(),
      )
      ..writeln()
      ..writeln('### Technical info')
      ..writeln()
      ..writeln('- App version: ${techInfo.appVersion}')
      ..writeln('- Platform: ${techInfo.platform}')
      ..writeln('- App language: ${techInfo.locale}')
      ..writeln('- Logged in: ${techInfo.connected ? 'yes' : 'no'}')
      ..writeln('- MGWS plugin: $mgws');
    if (lines.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('### Log (warnings and errors)')
        ..writeln()
        ..writeln('```text');
      if (truncated) buffer.writeln('… older lines removed …');
      for (final line in lines) {
        buffer.writeln(line);
      }
      buffer.writeln('```');
    }
    buffer
      ..writeln()
      ..writeln('_Sent from the app with the Feedback button._');
    return buffer.toString();
  }
}
