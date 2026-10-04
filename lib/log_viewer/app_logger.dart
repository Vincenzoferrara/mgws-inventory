import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Livelli di logging usati dal filtro pubblico del logger.
enum LogLevel {
  debug, // Dettagli tecnici, info operative e tracce diagnostiche.
  warning, // Anomalie non critiche, deprecazioni, fallback.
  error, // Errori critici che richiedono attenzione.
}

enum AppLogSeverity { trace, debug, info, warning, error, fatal }

/// Evento log già sanitizzato e pronto per viewer, console o file temporaneo.
class AppLogEvent {
  final DateTime timestamp;
  final AppLogSeverity severity;
  final String message;
  final String? error;
  final String? stackTrace;
  final String? tag;

  const AppLogEvent({
    required this.timestamp,
    required this.severity,
    required this.message,
    this.error,
    this.stackTrace,
    this.tag,
  });

  LogLevel get filterLevel {
    switch (severity) {
      case AppLogSeverity.warning:
        return LogLevel.warning;
      case AppLogSeverity.error:
      case AppLogSeverity.fatal:
        return LogLevel.error;
      case AppLogSeverity.trace:
      case AppLogSeverity.debug:
      case AppLogSeverity.info:
        return LogLevel.debug;
    }
  }

  String get formatted {
    final timestampText = _formatTimestamp(timestamp);
    final levelText = _levelLabels[severity] ?? 'UNKNOWN';
    final tagText = tag == null || tag!.trim().isEmpty
        ? ''
        : ' [${tag!.trim()}]';
    final buffer = StringBuffer('$timestampText [$levelText]$tagText $message');

    if (error != null && error!.isNotEmpty) {
      buffer.writeln();
      buffer.write('  Error: $error');
    }

    if (stackTrace != null && stackTrace!.isNotEmpty) {
      final lines = stackTrace!
          .split('\n')
          .where((line) => line.trim().isNotEmpty);
      for (final line in lines.take(12)) {
        buffer.writeln();
        buffer.write('  $line');
      }
    }

    return buffer.toString();
  }

  static String _formatTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    String three(int number) => number.toString().padLeft(3, '0');

    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}.${three(value.millisecond)}';
  }

  static const _levelLabels = {
    AppLogSeverity.trace: 'TRACE  ',
    AppLogSeverity.debug: 'DEBUG  ',
    AppLogSeverity.info: 'INFO   ',
    AppLogSeverity.warning: 'WARNING',
    AppLogSeverity.error: 'ERROR  ',
    AppLogSeverity.fatal: 'FATAL  ',
  };
}

/// Buffer circolare in memoria: sempre attivo, non tocca il disco.
class _MemoryLogBuffer {
  static const int _maxEvents = 2000;
  static const int _maxCharacters = 2 * 1024 * 1024;

  final _events = Queue<AppLogEvent>();
  int _characters = 0;

  List<AppLogEvent> get events => List.unmodifiable(_events);

  void add(AppLogEvent event) {
    _events.addLast(event);
    _characters += event.formatted.length;
    _trim();
  }

  void clear() {
    _events.clear();
    _characters = 0;
  }

  String dump({LogLevel? level, String? tag}) {
    final tagFilter = tag?.trim();
    final lines = _events
        .where((event) {
          final levelMatches = level == null || event.filterLevel == level;
          final tagMatches =
              tagFilter == null || tagFilter.isEmpty || event.tag == tagFilter;
          return levelMatches && tagMatches;
        })
        .map((event) => event.formatted);

    return lines.join('\n');
  }

  List<String> tags() {
    final values =
        _events
            .map((event) => event.tag?.trim())
            .whereType<String>()
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  void _trim() {
    while (_events.length > _maxEvents || _characters > _maxCharacters) {
      final removed = _events.removeFirst();
      _characters -= removed.formatted.length;
    }
  }
}

class _AsyncTempFileSink {
  static const int _maxBytes = 5 * 1024 * 1024;
  static const Duration _retention = Duration(days: 7);

  final File file;
  Future<void> _pendingWrite = Future.value();

  _AsyncTempFileSink(this.file);

  void write(String text) {
    _pendingWrite = _pendingWrite
        .then((_) async {
          await file.writeAsString(
            '$text\n',
            mode: FileMode.append,
            flush: false,
          );
          await _trimIfNeeded();
        })
        .catchError((Object error) {
          debugPrint('Error writing temporary log file: $error');
        });
  }

  Future<void> flush() => _pendingWrite;

  Future<void> _trimIfNeeded() async {
    if (!await file.exists()) return;
    final length = await file.length();
    if (length <= _maxBytes) return;

    final content = await file.readAsString();
    final keepFrom = content.length > _maxBytes ~/ 2
        ? content.length - (_maxBytes ~/ 2)
        : 0;
    await file.writeAsString(content.substring(keepFrom), flush: false);
  }

  static Future<void> cleanupExpired(Directory logDir) async {
    if (!await logDir.exists()) return;

    final now = DateTime.now();
    await for (final entity in logDir.list()) {
      if (entity is! File || !entity.path.endsWith('.txt')) continue;

      try {
        final modified = await entity.lastModified();
        if (now.difference(modified) > _retention) {
          await entity.delete();
        }
      } catch (error) {
        debugPrint('Error cleaning temporary log file: $error');
      }
    }
  }
}

/// Servizio di logging centralizzato.
///
/// Per default NON salva file: conserva solo un buffer temporaneo in memoria.
/// La scrittura su disco è temporanea e opt-in tramite [startTemporaryRecording]
/// o tramite snapshot per condivisione.
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  final _buffer = _MemoryLogBuffer();
  final _events = StreamController<AppLogEvent>.broadcast();
  _AsyncTempFileSink? _fileSink;
  File? _logFile;
  bool _initialized = false;
  LogLevel _minLevel = LogLevel.debug;

  /// Pattern per identificare informazioni sensibili.
  static final _sensitivePatterns = <RegExp>[
    RegExp(r'password["\s:=]+[^,}\s]+', caseSensitive: false),
    RegExp(r'passwd["\s:=]+[^,}\s]+', caseSensitive: false),
    RegExp(r'pwd["\s:=]+[^,}\s]+', caseSensitive: false),
    RegExp(r'token["\s:=]+[^,}\s]+', caseSensitive: false),
    RegExp(r'jwt["\s:=]+[^,}\s]+', caseSensitive: false),
    RegExp(r'bearer\s+[a-zA-Z0-9\-._~+/]+=*', caseSensitive: false),
    RegExp(r'authorization["\s:]+bearer\s+[^,}\s]+', caseSensitive: false),
    RegExp(r'api[_-]?key["\s:=]+[^,}\s]+', caseSensitive: false),
    RegExp(r'app[_-]?password["\s:=]+[^,}\s]+', caseSensitive: false),
    RegExp(r'secret["\s:=]+[^,}\s]+', caseSensitive: false),
    RegExp(r'consumer[_-]?(key|secret)["\s:=]+[^,}\s]+', caseSensitive: false),
    RegExp(r'\b(c[ks]_[a-zA-Z0-9]{20,})\b', caseSensitive: false),
  ];

  Stream<AppLogEvent> get events => _events.stream;
  bool get isRecording => _fileSink != null;
  String? get currentLogPath => _logFile?.path;

  String get memoryLogContent => _buffer.dump();
  List<String> get availableTags => _buffer.tags();

  Future<void> init({LogLevel minLevel = LogLevel.debug}) async {
    _minLevel = minLevel;
    if (_initialized) return;

    _initialized = true;
    try {
      await _AsyncTempFileSink.cleanupExpired(await _temporaryLogDirectory());
      _write(
        AppLogSeverity.debug,
        'Logger initialized - Level: ${minLevel.name} - Mode: memory only',
      );
    } catch (error) {
      debugPrint('Error initializing logger: $error');
    }
  }

  void setMinLevel(LogLevel level) {
    _minLevel = level;
    _write(
      AppLogSeverity.info,
      'Logger level changed to ${level.name}',
      tag: 'logger',
    );
  }

  Future<void> startTemporaryRecording() async {
    if (!_initialized) await init();
    if (_fileSink != null) return;

    final logDir = await _temporaryLogDirectory();
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final now = DateTime.now();
    final fileName =
        'app_log_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.txt';
    _logFile = File('${logDir.path}/$fileName');
    _fileSink = _AsyncTempFileSink(_logFile!);
    _write(
      AppLogSeverity.info,
      'Temporary log recording started: ${_logFile!.path}',
      tag: 'logger',
    );
  }

  Future<void> stopTemporaryRecording() async {
    final sink = _fileSink;
    if (sink == null) return;

    _write(
      AppLogSeverity.info,
      'Temporary log recording stopped',
      tag: 'logger',
    );
    await sink.flush();
    _fileSink = null;
  }

  Future<File?> createTemporarySnapshot({String? content}) async {
    final text = content ?? memoryLogContent;
    if (text.trim().isEmpty) return null;

    final logDir = await _temporaryLogDirectory();
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final now = DateTime.now();
    final file = File(
      '${logDir.path}/app_log_snapshot_${now.millisecondsSinceEpoch}.txt',
    );
    await file.writeAsString(text, flush: true);
    return file;
  }

  Future<List<File>> getAllLogFiles() async {
    try {
      final logDir = await _temporaryLogDirectory();
      await _AsyncTempFileSink.cleanupExpired(logDir);

      if (!await logDir.exists()) return [];

      final files = await logDir.list().toList();
      return files
          .whereType<File>()
          .where((file) => file.path.endsWith('.txt'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
    } catch (error) {
      debugPrint('Error reading temporary log files: $error');
      return [];
    }
  }

  Future<String> readLogFile(File file) async {
    try {
      return await file.readAsString();
    } catch (error) {
      return 'Error reading file: $error';
    }
  }

  Future<void> clearAllLogs() async {
    try {
      final sink = _fileSink;
      if (sink != null) await sink.flush();
      _fileSink = null;
      _logFile = null;
      _buffer.clear();

      final files = await getAllLogFiles();
      for (final file in files) {
        if (await file.exists()) {
          await file.delete();
        }
      }

      debugPrint('All temporary logs cleared (${files.length} files)');
    } catch (error) {
      debugPrint('Error clearing logs: $error');
    }
  }

  void v(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _write(AppLogSeverity.trace, message, error: error, stackTrace: stackTrace);
  }

  void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _write(AppLogSeverity.debug, message, error: error, stackTrace: stackTrace);
  }

  void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _write(AppLogSeverity.info, message, error: error, stackTrace: stackTrace);
  }

  void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _write(
      AppLogSeverity.warning,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _write(AppLogSeverity.error, message, error: error, stackTrace: stackTrace);
  }

  void f(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _write(AppLogSeverity.fatal, message, error: error, stackTrace: stackTrace);
  }

  void _write(
    AppLogSeverity severity,
    dynamic message, {
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (!_initialized) return;
    if (!_shouldLog(severity)) return;

    final event = AppLogEvent(
      timestamp: DateTime.now(),
      severity: severity,
      message: _sanitize(message),
      error: error == null ? null : _sanitize(error),
      stackTrace: stackTrace == null ? null : _sanitize(stackTrace),
      tag: tag,
    );

    _buffer.add(event);
    _events.add(event);

    if (!kReleaseMode) {
      debugPrint(event.formatted);
    }

    _fileSink?.write(event.formatted);
  }

  bool _shouldLog(AppLogSeverity severity) {
    switch (_minLevel) {
      case LogLevel.debug:
        return true;
      case LogLevel.warning:
        return severity.index >= AppLogSeverity.warning.index;
      case LogLevel.error:
        return severity.index >= AppLogSeverity.error.index;
    }
  }

  String _sanitize(dynamic message) {
    if (message == null) return 'null';

    var text = message.toString();
    for (final pattern in _sensitivePatterns) {
      text = text.replaceAllMapped(pattern, (match) {
        final matched = match.group(0) ?? '';
        if (matched.contains(':') || matched.contains('=')) {
          final separator = matched.contains(':') ? ':' : '=';
          final parts = matched.split(separator);
          return '${parts[0]}$separator ***REDACTED***';
        }
        return '***REDACTED***';
      });
    }

    text = text.replaceAllMapped(
      RegExp(r'eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+'),
      (match) => '***JWT_TOKEN_REDACTED***',
    );

    return text;
  }

  Future<Directory> _temporaryLogDirectory() async {
    final directory = await getTemporaryDirectory();
    return Directory('${directory.path}/mgws_inventory_logs');
  }
}

/// Shortcut globale per accedere al logger.
final log = AppLogger();
