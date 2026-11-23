import 'package:material_ui/material_ui.dart';

import 'dashboard.code.dart';

class DashboardReportPanel extends StatelessWidget {
  const DashboardReportPanel({
    super.key,
    required this.dashboardData,
    required this.filter,
    required this.availableCapabilities,
    required this.missingCapabilities,
    required this.onGenerateReport,
    required this.isExporting,
  });

  static const rootKey = ValueKey('dashboard-report-panel-root');
  static const activeFilterLabelKey = ValueKey(
    'dashboard-report-panel-active-filter-label',
  );
  static const generateReportButtonKey = ValueKey(
    'dashboard-report-panel-generate-report-button',
  );
  static const double _compactBreakpoint = 600;
  static const double _expandedBreakpoint = 840;

  final DashboardData dashboardData;
  final DashboardAnalysisFilter filter;
  final List<String> availableCapabilities;
  final List<String> missingCapabilities;
  final VoidCallback onGenerateReport;
  final bool isExporting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      key: rootKey,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          final isCompact = outerConstraints.maxWidth < _compactBreakpoint;
          final panelPadding = isCompact ? 16.0 : 20.0;

          return Padding(
            padding: EdgeInsets.all(panelPadding),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isExpanded = constraints.maxWidth >= _expandedBreakpoint;
                final header = _PanelHeader(
                  filter: filter,
                  dashboardData: dashboardData,
                  isExporting: isExporting,
                  onGenerateReport: onGenerateReport,
                );
                final capabilities = _CapabilitySummary(
                  availableCapabilities: availableCapabilities,
                  missingCapabilities: missingCapabilities,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isExpanded)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: header),
                          const SizedBox(width: 20),
                          Expanded(flex: 4, child: capabilities),
                        ],
                      )
                    else ...[
                      header,
                      const SizedBox(height: 20),
                      capabilities,
                    ],
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: scheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'La dashboard e lo spazio interattivo di analisi. '
                                'Il report genera file PDF o CSV usando il periodo '
                                'e i dati attualmente caricati nella dashboard.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.filter,
    required this.dashboardData,
    required this.isExporting,
    required this.onGenerateReport,
  });

  final DashboardAnalysisFilter filter;
  final DashboardData dashboardData;
  final bool isExporting;
  final VoidCallback onGenerateReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitleColor = scheme.onSurface.withValues(alpha: 0.68);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxWidth < DashboardReportPanel._compactBreakpoint;
        final icon = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.analytics_outlined, color: scheme.primary),
        );
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analisi dashboard',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Workspace interattivo per leggere vendite, ordini e stock.',
              style: theme.textTheme.bodyMedium?.copyWith(color: subtitleColor),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCompact) ...[
              icon,
              const SizedBox(height: 12),
              title,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(child: title),
                ],
              ),
            const SizedBox(height: 16),
            Text(
              filter.summaryText,
              key: DashboardReportPanel.activeFilterLabelKey,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, chipConstraints) {
                final chipMaxWidth = chipConstraints.maxWidth;

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(
                      icon: Icons.shopping_cart_outlined,
                      label: '${dashboardData.vendite.numeroOrdini} ordini',
                      maxWidth: chipMaxWidth,
                    ),
                    _MetricChip(
                      icon: Icons.inventory_2_outlined,
                      label:
                          '${dashboardData.prodotti.totaleProdotti} prodotti',
                      maxWidth: chipMaxWidth,
                    ),
                    _MetricChip(
                      icon: Icons.receipt_long_outlined,
                      label:
                          '${dashboardData.ordini.totaleOrdini} stati ordine',
                      maxWidth: chipMaxWidth,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            if (isCompact)
              SizedBox(width: double.infinity, child: _buildReportButton())
            else
              _buildReportButton(),
          ],
        );
      },
    );
  }

  Widget _buildReportButton() {
    return ElevatedButton.icon(
      key: DashboardReportPanel.generateReportButtonKey,
      onPressed: isExporting ? null : onGenerateReport,
      icon: isExporting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_download_outlined),
      label: Text(isExporting ? 'Generazione...' : 'Genera report'),
    );
  }
}

class _CapabilitySummary extends StatelessWidget {
  const _CapabilitySummary({
    required this.availableCapabilities,
    required this.missingCapabilities,
  });

  final List<String> availableCapabilities;
  final List<String> missingCapabilities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dati analizzabili ora',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final capability in availableCapabilities)
                  _CapabilityChip(
                    label: capability,
                    enabled: true,
                    maxWidth: constraints.maxWidth,
                  ),
              ],
            );
          },
        ),
        if (missingCapabilities.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'In arrivo quando l\'aggregazione sara disponibile',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final capability in missingCapabilities)
                    _CapabilityChip(
                      label: capability,
                      enabled: false,
                      maxWidth: constraints.maxWidth,
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({
    required this.label,
    required this.enabled,
    required this.maxWidth,
  });

  final String label;
  final bool enabled;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = enabled ? scheme.primary : scheme.outline;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Chip(
        avatar: Icon(
          enabled ? Icons.check_circle_outline : Icons.schedule_outlined,
          size: 18,
          color: color,
        ),
        label: Text(label, overflow: TextOverflow.ellipsis),
        labelStyle: TextStyle(
          color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
          fontWeight: enabled ? FontWeight.w600 : FontWeight.w500,
        ),
        backgroundColor: enabled
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        side: BorderSide(color: color.withValues(alpha: enabled ? 0.28 : 0.18)),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.maxWidth,
  });

  final IconData icon;
  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
