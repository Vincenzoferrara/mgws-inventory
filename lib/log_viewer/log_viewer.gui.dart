import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mgws_inventory/theme/theme.dart';
import 'package:share_plus/share_plus.dart';
import '../notification/notification_service.dart';
import 'app_logger.dart';
import '../traduzioni/estensioni.dart';

/// Schermata per visualizzare i log dell'applicazione
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  List<File> _logFiles = [];
  File? _selectedFile;
  String _logContent = '';
  String _filteredContent = '';
  bool _isLoading = false;
  int _totalLines = 0;
  int _filteredLines = 0;
  LogLevel? _selectedLogLevel; // null = mostra tutto
  String? _selectedTag; // null = mostra tutti i tag
  List<String> _availableTags = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<AppLogEvent>? _logSubscription;
  bool _isRecordingLogs = false;

  @override
  void initState() {
    super.initState();
    _isRecordingLogs = log.isRecording;
    _availableTags = log.availableTags;
    _logSubscription = log.events.listen((_) {
      if (!mounted) return;
      _availableTags = log.availableTags;
      if (_selectedFile == null) {
        _loadMemoryContent();
      } else {
        setState(() {});
      }
    });
    _loadLogFiles();
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLogFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await log.getAllLogFiles();
      final uniqueByPath = <String, File>{};
      for (final file in files) {
        uniqueByPath[file.path] = file;
      }
      final dedupedFiles = uniqueByPath.values.toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      File? nextSelected;
      final selectedPath = _selectedFile?.path;
      if (selectedPath != null) {
        for (final file in dedupedFiles) {
          if (file.path == selectedPath) {
            nextSelected = file;
            break;
          }
        }
      }

      setState(() {
        _logFiles = dedupedFiles;
        _selectedFile = nextSelected;
        _availableTags = log.availableTags;
        _isRecordingLogs = log.isRecording;
      });

      if (_selectedFile != null) {
        await _loadLogContent();
      } else {
        _loadMemoryContent();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadMemoryContent() {
    final content = log.memoryLogContent;
    final lines = content.split('\n').where((line) => line.isNotEmpty).toList();

    setState(() {
      _logContent = content;
      _totalLines = lines.length;
      _availableTags = log.availableTags;
      _applyFilter();
    });
  }

  Future<void> _loadLogContent() async {
    if (_selectedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final content = await log.readLogFile(_selectedFile!);
      final lines = content
          .split('\n')
          .where((line) => line.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _logContent = content;
        _totalLines = lines.length;
        _applyFilter();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final lines = _logContent.split('\n');
    final filteredLines = <String>[];

    String? levelPattern;
    if (_selectedLogLevel != null) {
      switch (_selectedLogLevel!) {
        case LogLevel.debug:
          levelPattern = '[DEBUG  ]';
          break;
        case LogLevel.warning:
          levelPattern = '[WARNING]';
          break;
        case LogLevel.error:
          levelPattern = '[ERROR  ]';
          break;
      }
    }

    for (final line in lines) {
      final levelMatches = levelPattern == null || line.contains(levelPattern);
      final tagMatches =
          _selectedTag == null ||
          _selectedTag!.isEmpty ||
          line.contains('[${_selectedTag!}]');

      if (levelMatches && tagMatches) {
        filteredLines.add(line);
      }
    }

    _filteredContent = filteredLines.join('\n');
    _filteredLines = filteredLines.length;
  }

  void _setLogLevelFilter(LogLevel? level) {
    setState(() {
      _selectedLogLevel = level;
      _applyFilter();
    });
  }

  void _setTagFilter(String? tag) {
    setState(() {
      _selectedTag = tag;
      _applyFilter();
    });
  }

  void _copyToClipboard() {
    if (_filteredContent.isEmpty) return;

    Clipboard.setData(ClipboardData(text: _filteredContent));
    NotificationService.instance.messageBar(
      'successo',
      'log_viewer',
      '$_filteredLines righe copiate negli appunti',
    );
  }

  Future<void> _clearLogs() async {
    // Cattura il tema PRIMA del dialog per evitare problemi di context
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColorExtension>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.logConfermaCancellazioneTitolo),
        content: Text(context.l10n.logConfermaCancellazioneTesto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: appColors?.errorColorStatus ?? colorScheme.error,
            ),
            child: Text(context.l10n.logCancella),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await log.clearAllLogs();
      _selectedFile = null;
      await _loadLogFiles();
      if (mounted) {
        NotificationService.instance.messageBar(
          'warning',
          'log_viewer',
          'Contenuto log cancellato',
        );
      }
    }
  }

  Future<void> _toggleTemporaryRecording() async {
    if (_isRecordingLogs) {
      await log.stopTemporaryRecording();
    } else {
      await log.startTemporaryRecording();
    }

    await _loadLogFiles();
    if (!mounted) return;
    NotificationService.instance.messageBar(
      'successo',
      'log_viewer',
      log.isRecording
          ? 'Registrazione temporanea avviata'
          : 'Registrazione temporanea fermata',
    );
  }

  Future<void> _shareAndClearLogs() async {
    if (_filteredContent.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await log.stopTemporaryRecording();
      final file = await log.createTemporarySnapshot(content: _filteredContent);
      if (file == null) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Log temporaneo mgws_inventory',
        ),
      );
      await log.clearAllLogs();
      if (await file.exists()) {
        await file.delete();
      }
      _selectedFile = null;
      await _loadLogFiles();

      if (!mounted) return;
      NotificationService.instance.messageBar(
        'successo',
        'log_viewer',
        'Log condiviso e memoria temporanea svuotata',
      );
    } catch (error) {
      if (!mounted) return;
      NotificationService.instance.messageBar(
        'errore',
        'log_viewer',
        'Errore condivisione log: $error',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.logTitolo),
        actions: [
          // Numero righe
          if (_totalLines > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _selectedLogLevel == null
                        ? '$_totalLines righe'
                        : '$_filteredLines / $_totalLines righe',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          // Copia
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: context.l10n.logCopiaTutto,
            onPressed: _filteredContent.isNotEmpty ? _copyToClipboard : null,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Condividi log temporaneo e pulisci',
            onPressed: _filteredContent.isNotEmpty ? _shareAndClearLogs : null,
          ),
          IconButton(
            icon: Icon(
              _isRecordingLogs
                  ? Icons.stop_circle_outlined
                  : Icons.fiber_manual_record,
            ),
            tooltip: _isRecordingLogs
                ? 'Ferma registrazione temporanea'
                : 'Avvia registrazione temporanea',
            color: _isRecordingLogs
                ? Theme.of(context).colorScheme.error
                : null,
            onPressed: _toggleTemporaryRecording,
          ),
          // Cancella
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: context.l10n.logCancellaLog,
            onPressed: _clearLogs,
          ),
          // Ricarica
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.commonRefresh,
            onPressed: _loadLogFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra filtri
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              children: [
                // Selettore sorgente log: buffer memoria oppure file temporanei.
                if (_logFiles.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.storage_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedFile?.path ?? '__memory__',
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: '__memory__',
                              child: Text('Buffer memoria temporaneo'),
                            ),
                            ..._logFiles.map((file) {
                              final name = file.path.split('/').last;
                              return DropdownMenuItem<String>(
                                value: file.path,
                                child: Text(name),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            if (value == '__memory__') {
                              _selectedFile = null;
                              _loadMemoryContent();
                              return;
                            }

                            File? file;
                            for (final candidate in _logFiles) {
                              if (candidate.path == value) {
                                file = candidate;
                                break;
                              }
                            }
                            if (file != null) {
                              setState(() => _selectedFile = file);
                              _loadLogContent();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                // Filtro livello log
                Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Filtra per livello:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButton<LogLevel?>(
                        value: _selectedLogLevel,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem<LogLevel?>(
                            value: null,
                            child: Row(
                              children: [
                                const Icon(Icons.all_inclusive, size: 18),
                                const SizedBox(width: 8),
                                Text(context.l10n.logTuttiLivelli),
                              ],
                            ),
                          ),
                          DropdownMenuItem<LogLevel?>(
                            value: LogLevel.debug,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bug_report,
                                  size: 18,
                                  color: context.colors.infoColor,
                                ),
                                const SizedBox(width: 8),
                                const Text('DEBUG'),
                              ],
                            ),
                          ),
                          DropdownMenuItem<LogLevel?>(
                            value: LogLevel.warning,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  size: 18,
                                  color: context.colors.warningColor,
                                ),
                                const SizedBox(width: 8),
                                const Text('WARNING'),
                              ],
                            ),
                          ),
                          DropdownMenuItem<LogLevel?>(
                            value: LogLevel.error,
                            child: Row(
                              children: [
                                Icon(Icons.error, size: 18, color: context.colors.errorColorStatus),
                                const SizedBox(width: 8),
                                const Text('ERROR'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (level) => _setLogLevelFilter(level),
                      ),
                    ),
                  ],
                ),
                if (_availableTags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.label_outline,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Filtra per tag:',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<String?>(
                          value: _selectedTag,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Tutti i tag'),
                            ),
                            ..._availableTags.map(
                              (tag) => DropdownMenuItem<String?>(
                                value: tag,
                                child: Text(tag),
                              ),
                            ),
                          ],
                          onChanged: _setTagFilter,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loadLogFiles,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.logRicaricaLog),
                    ),
                    OutlinedButton.icon(
                      onPressed: _toggleTemporaryRecording,
                      icon: Icon(
                        _isRecordingLogs
                            ? Icons.stop_circle_outlined
                            : Icons.fiber_manual_record,
                      ),
                      label: Text(
                        _isRecordingLogs
                            ? 'Ferma log temporaneo'
                            : 'Registra log temporaneo',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _filteredContent.isNotEmpty
                          ? _shareAndClearLogs
                          : null,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Condividi e pulisci'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Contenuto log
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContent.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedLogLevel != null
                              ? Icons.filter_list_off
                              : Icons.description_outlined,
                          size: 64,
                          color: context.colors.neutralColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedLogLevel != null
                              ? 'Nessun log per il livello selezionato'
                              : 'Nessun log disponibile',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: context.colors.subtitleColor),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          _filteredContent,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                      // Pulsanti scroll
                      Positioned(
                        right: 16,
                        bottom: 80,
                        child: Column(
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'scroll_top',
                              onPressed: _scrollToTop,
                              child: const Icon(Icons.arrow_upward),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              heroTag: 'scroll_bottom',
                              onPressed: _scrollToBottom,
                              child: const Icon(Icons.arrow_downward),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
