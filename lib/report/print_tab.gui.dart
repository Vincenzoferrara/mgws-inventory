import 'package:flutter/material.dart';

import '../notification/notification_service.dart';
import '../prodotti/prodotti_gestisci/product_picker.dart';
import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';
import 'paper_format.dart';
import 'print_job.dart';
import 'print_pdf_renderer.dart';
import 'print_preview.gui.dart';
import 'print_template.dart';
import 'print_widgets.gui.dart';
import 'report.code.dart';

/// Print tab: every template grouped by category; tapping one shows the
/// preview and the print settings. When labels were requested from the
/// products list, only product labels are listed and they print the real
/// products.
class PrintTab extends StatelessWidget {
  const PrintTab({super.key, required this.controller});

  final PrintCenterController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: controller.isPrinting
          ? _PrintSettingsView(
              key: const ValueKey('settings'),
              controller: controller,
            )
          : _ChooseTemplateView(
              key: const ValueKey('choose'),
              controller: controller,
            ),
    );
  }
}

class _ChooseTemplateView extends StatelessWidget {
  const _ChooseTemplateView({super.key, required this.controller});

  final PrintCenterController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final job = controller.job;
    return ListView(
      padding: context.spacing.iL,
      children: [
        if (job != null) ...[
          _JobBanner(controller: controller, job: job),
          SizedBox(height: context.spacing.m),
        ],
        Text(
          job == null
              ? l10n.reportTemplateQuestion
              : l10n.reportJobTemplateQuestion,
          style: context.text.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: context.spacing.xs),
        Text(
          l10n.reportPrintHelp,
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.subtitleColor,
          ),
        ),
        PrintTemplateGroups(
          library: controller.library,
          where: controller.accepts,
          onTap: controller.chooseTemplate,
        ),
      ],
    );
  }
}

class _JobBanner extends StatelessWidget {
  const _JobBanner({required this.controller, required this.job});

  final PrintCenterController controller;
  final PrintJob job;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      color: context.theme.colorScheme.primaryContainer,
      child: Padding(
        padding: context.spacing.iL,
        child: Row(
          children: [
            Icon(
              Icons.sell_outlined,
              color: context.theme.colorScheme.onPrimaryContainer,
            ),
            SizedBox(width: context.spacing.m),
            Expanded(
              child: Text(
                l10n.reportJobSummary(job.items.length, job.totalLabels),
                style: context.text.titleSmall?.copyWith(
                  color: context.theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: controller.clearJob,
              icon: const Icon(Icons.close),
              label: Text(l10n.reportJobCancel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintSettingsView extends StatefulWidget {
  const _PrintSettingsView({super.key, required this.controller});

  final PrintCenterController controller;

  @override
  State<_PrintSettingsView> createState() => _PrintSettingsViewState();
}

class _PrintSettingsViewState extends State<_PrintSettingsView> {
  // Sheets open on the whole sheet: every label, real data and the skipped
  // positions are visible at once.
  bool _showWholeSheet = true;
  bool _busy = false;

  PrintCenterController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final paper = _controller.paper!;
    final canZoom = paper.isMultiCellSheet;
    final preview = _PreviewPanel(
      request: _controller.request(
        context.l10n,
        preview: true,
        singleCell: canZoom && !_showWholeSheet,
      ),
      canSwitchView: canZoom,
      showWholeSheet: _showWholeSheet,
      hasRealData: _controller.job != null,
      onViewChanged: (value) => setState(() => _showWholeSheet = value),
    );
    final settings = _SettingsPanel(controller: _controller);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 920;
        return Column(
          children: [
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 400,
                          child: ListView(
                            padding: context.spacing.iL,
                            children: [settings],
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: preview),
                      ],
                    )
                  // On narrow screens the preview stays fixed on top and only
                  // the settings scroll, so every change is seen at once.
                  : Column(
                      children: [
                        SizedBox(
                          height: (constraints.maxHeight * 0.45).clamp(
                            220.0,
                            460.0,
                          ),
                          child: preview,
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView(
                            padding: context.spacing.iL,
                            children: [settings],
                          ),
                        ),
                      ],
                    ),
            ),
            _PrintActionBar(
              busy: _busy,
              canPrint: _controller.canPrint,
              onPrint: () => _run(_controller.printSelected),
              onShare: () => _run(_controller.shareSelected),
            ),
          ],
        );
      },
    );
  }

  Future<void> _run(Future<void> Function(AppLocalizations l10n) action) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await action(l10n);
    } catch (error) {
      NotificationService.instance.messageBar(
        'errore',
        'report',
        l10n.reportPrintError(error.toString()),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.controller});

  final PrintCenterController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final template = controller.template!;
    final paper = controller.paper!;
    final job = controller.job;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: l10n.reportChangeTemplate,
              icon: const Icon(Icons.arrow_back),
              onPressed: controller.closeTemplate,
            ),
            Expanded(
              child: Text(
                template.name,
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (template.kind == PrintTemplateKind.report) ...[
          SizedBox(height: context.spacing.m),
          InfoBox(text: l10n.reportReportSampleExplanation),
        ] else if (job != null)
          EditorSection(
            icon: Icons.sell_outlined,
            title: l10n.reportJobLabelsTitle,
            child: _JobQuantities(
              controller: controller,
              job: job,
              paper: paper,
            ),
          )
        else
          EditorSection(
            icon: Icons.content_copy_outlined,
            title: l10n.reportSectionQuantity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QuantityEditor(controller: controller, paper: paper),
                if (template.kind == PrintTemplateKind.productLabel) ...[
                  SizedBox(height: context.spacing.l),
                  Text(
                    l10n.reportAddLabelsHelp,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.subtitleColor,
                    ),
                  ),
                  SizedBox(height: context.spacing.s),
                  _AddLabelsButton(controller: controller),
                ],
              ],
            ),
          ),
        EditorSection(
          icon: Icons.straighten,
          title: l10n.reportSectionPaper,
          child: PaperPicker(
            formats: controller.library.paperFormatsFor(template.kind),
            selectedId: paper.id,
            onSelected: controller.setPaper,
          ),
        ),
      ],
    );
  }
}

class _QuantityEditor extends StatelessWidget {
  const _QuantityEditor({required this.controller, required this.paper});

  final PrintCenterController controller;
  final PaperFormat paper;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSheet = paper.isMultiCellSheet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.reportCopiesQuestion, style: context.text.bodyMedium),
        SizedBox(height: context.spacing.s),
        Wrap(
          spacing: context.spacing.s,
          runSpacing: context.spacing.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            NumberStepper(
              value: controller.copies,
              min: 1,
              max: 999,
              onChanged: controller.setCopies,
            ),
            if (isSheet && controller.copies != paper.cellsPerPage)
              ActionChip(
                avatar: const Icon(Icons.grid_on, size: 18),
                label: Text(l10n.reportFullSheet(paper.cellsPerPage)),
                onPressed: () => controller.setCopies(paper.cellsPerPage),
              ),
          ],
        ),
        if (isSheet) _SkipEditor(controller: controller, paper: paper),
      ],
    );
  }
}

/// One line per product or variant, with its labels to print.
class _JobQuantities extends StatelessWidget {
  const _JobQuantities({
    required this.controller,
    required this.job,
    required this.paper,
  });

  final PrintCenterController controller;
  final PrintJob job;
  final PaperFormat paper;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.reportJobQuantityHelp,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.subtitleColor,
          ),
        ),
        SizedBox(height: context.spacing.s),
        _AddLabelsButton(controller: controller),
        SizedBox(height: context.spacing.s),
        if (job.items.isEmpty)
          Text(l10n.reportJobEmpty, style: context.text.bodyMedium),
        for (final item in job.items)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        [
                          if (item.color.isNotEmpty) item.color,
                          if (item.size.isNotEmpty) item.size,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.spacing.s),
                Text(
                  l10n.reportJobLabelCount(item.quantity),
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  tooltip: l10n.reportJobRemove,
                  icon: Icon(
                    Icons.delete_outline,
                    color: context.colors.errorColorStatus,
                  ),
                  onPressed: () => controller.removeJobItem(item.key),
                ),
              ],
            ),
          ),
        if (paper.isMultiCellSheet)
          _SkipEditor(controller: controller, paper: paper),
      ],
    );
  }
}

/// Opens the product picker shared with the till and the inventory and adds
/// the chosen products and variants to the labels: one label per piece in
/// stock, variants without pieces and lines already listed are skipped.
class _AddLabelsButton extends StatelessWidget {
  const _AddLabelsButton({required this.controller});

  final PrintCenterController controller;

  Future<void> _add(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await openProdottoPicker(context);
    if (picked == null || picked.isEmpty) return;
    final more = PrintJob.fromProducts(picked);
    if (more.items.isEmpty) {
      NotificationService.instance.messageBar(
        'warning',
        'report',
        l10n.productsPrintLabelsNoStock,
      );
      return;
    }
    final added = controller.addToJob(more);
    if (added == 0) {
      NotificationService.instance.messageBar(
        'info',
        'report',
        l10n.reportAddLabelsAlreadyListed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _add(context),
      icon: const Icon(Icons.add),
      label: Text(context.l10n.reportAddLabels),
    );
  }
}

/// One "positions already used" counter per sheet to print. Only shown for
/// sheets with more than one label: rolls always start from the first label.
class _SkipEditor extends StatelessWidget {
  const _SkipEditor({required this.controller, required this.paper});

  final PrintCenterController controller;
  final PaperFormat paper;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skips = controller.sheetSkips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: context.spacing.l),
        Text(l10n.reportSkipQuestion, style: context.text.bodyMedium),
        SizedBox(height: context.spacing.xs),
        Text(
          l10n.reportSkipHelp,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.subtitleColor,
          ),
        ),
        SizedBox(height: context.spacing.s),
        for (var sheet = 0; sheet < skips.length; sheet++)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.reportSheetNumber(sheet + 1),
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                NumberStepper(
                  value: skips[sheet],
                  min: 0,
                  max: paper.cellsPerPage - 1,
                  onChanged: (value) =>
                      controller.setSkippedCells(sheet, value),
                ),
              ],
            ),
          ),
        SizedBox(height: context.spacing.m),
        Text(
          l10n.reportSheetsNeeded(skips.length),
          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.request,
    required this.canSwitchView,
    required this.showWholeSheet,
    required this.hasRealData,
    required this.onViewChanged,
  });

  final PrintRequest request;
  final bool canSwitchView;
  final bool showWholeSheet;
  final bool hasRealData;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notice = canSwitchView && showWholeSheet
        ? l10n.reportPreviewSheetNotice
        : hasRealData
        ? l10n.reportPreviewRealNotice
        : l10n.reportPreviewSampleNotice;
    return Container(
      color: context.theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.spacing.l,
              context.spacing.m,
              context.spacing.l,
              context.spacing.s,
            ),
            child: Wrap(
              spacing: context.spacing.m,
              runSpacing: context.spacing.s,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  l10n.reportPreviewTitle,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (canSwitchView)
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.zoom_in),
                        label: Text(l10n.reportPreviewOneLabel),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.grid_view),
                        label: Text(l10n.reportPreviewWholeSheet),
                      ),
                    ],
                    selected: {showWholeSheet},
                    onSelectionChanged: (selection) =>
                        onViewChanged(selection.first),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.l),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: context.colors.subtitleColor,
                ),
                SizedBox(width: context.spacing.xs),
                Expanded(
                  child: Text(
                    notice,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: PdfPagesView(request: request)),
        ],
      ),
    );
  }
}

class _PrintActionBar extends StatelessWidget {
  const _PrintActionBar({
    required this.busy,
    required this.canPrint,
    required this.onPrint,
    required this.onShare,
  });

  final bool busy;
  final bool canPrint;
  final VoidCallback onPrint;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = !busy && canPrint;
    return Material(
      elevation: 6,
      color: context.theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.l,
            vertical: context.spacing.m,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: OutlinedButton.icon(
                  onPressed: enabled ? onShare : null,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(l10n.reportSavePdf),
                ),
              ),
              SizedBox(width: context.spacing.m),
              Flexible(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 18,
                    ),
                    textStyle: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: enabled ? onPrint : null,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print),
                  label: Text(l10n.commonPrint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
