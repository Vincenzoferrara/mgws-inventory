import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';
import 'print_job.dart';
import 'print_library.dart';
import 'print_tab.gui.dart';
import 'report.code.dart';
import 'template_tab.gui.dart';

/// "Templates and print" section: the Print tab prints labels, signs and
/// reports; the Template tab manages templates, categories and paper formats.
/// Everything is stored by MGWS, so the section opens only when MGWS works.
class PrintCenterPage extends StatefulWidget {
  const PrintCenterPage({super.key});

  @override
  State<PrintCenterPage> createState() => _PrintCenterPageState();
}

class _PrintCenterPageState extends State<PrintCenterPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final PrintCenterController _controller = PrintCenterController();
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    printLibrary.addListener(_controller.syncWithLibrary);
    pendingPrintJob.addListener(_takePendingJob);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      printLibrary.load(context.l10n);
      _takePendingJob();
    });
  }

  @override
  void dispose() {
    printLibrary.removeListener(_controller.syncWithLibrary);
    pendingPrintJob.removeListener(_takePendingJob);
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  /// A job sent from another section (e.g. the products list) opens the
  /// Print tab on it.
  void _takePendingJob() {
    final job = pendingPrintJob.value;
    if (job == null) return;
    pendingPrintJob.value = null;
    _controller.startJob(job);
    _tabs.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.reportPrintCenterTitle),
        actions: [
          IconButton(
            tooltip: l10n.reportReload,
            icon: const Icon(Icons.refresh),
            onPressed: () => printLibrary.load(l10n, force: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              icon: const Icon(Icons.print_outlined),
              text: l10n.reportTabPrint,
            ),
            Tab(
              icon: const Icon(Icons.dashboard_customize_outlined),
              text: l10n.reportTabTemplates,
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([printLibrary, _controller]),
        builder: (context, _) {
          if (!printLibrary.loaded) {
            return _LoadState(
              loading: printLibrary.loading || printLibrary.error == null,
              onRetry: () => printLibrary.load(l10n, force: true),
            );
          }
          return TabBarView(
            controller: _tabs,
            children: [
              PrintTab(controller: _controller),
              TemplateTab(library: printLibrary),
            ],
          );
        },
      ),
    );
  }
}

class _LoadState extends StatelessWidget {
  const _LoadState({required this.loading, required this.onRetry});

  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: context.spacing.iXL,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: context.colors.subtitleColor,
            ),
            SizedBox(height: context.spacing.m),
            Text(l10n.reportLoadError, textAlign: TextAlign.center),
            SizedBox(height: context.spacing.m),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.reportReload),
            ),
          ],
        ),
      ),
    );
  }
}
