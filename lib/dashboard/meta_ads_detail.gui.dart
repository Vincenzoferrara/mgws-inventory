// Meta Ads Detail - Finestra dettagliata per Meta Ads (Facebook/Instagram)

import 'package:flutter/material.dart';
import 'ads_dashboard.code.dart';
import '../theme/theme.dart';
import '../traduzioni/estensioni.dart';

/// Finestra dettagliata per visualizzare campagne e insights Meta Ads
class MetaAdsDetailPage extends StatefulWidget {
  final AdsPlatformService adsService;
  final String? adAccountId;

  const MetaAdsDetailPage({
    super.key,
    required this.adsService,
    this.adAccountId,
  });

  @override
  State<MetaAdsDetailPage> createState() => _MetaAdsDetailPageState();
}

class _MetaAdsDetailPageState extends State<MetaAdsDetailPage> {
  AdsPlatformData? _data;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!widget.adsService.isConnected("meta")) {
      setState(() {
        _errorMessage =
            "Non sei connesso a Meta Ads. Effettua il login dalla dashboard principale.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await widget.adsService.fetchAllData(
        metaAdAccountId: widget.adAccountId,
      );

      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Errore caricamento dati Meta Ads: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.facebook, color: context.colors.infoColor),
            const SizedBox(width: 8),
            const Text("Meta Ads - Dettagli"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: "Ricarica dati",
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: context.colors.errorColorStatus,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: context.spacing.iL,
              child: Text(_errorMessage!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text("Riprova")),
          ],
        ),
      );
    }

    if (_data == null || _data!.metaCampaigns == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: context.colors.subtitleColor,
            ),
            const SizedBox(height: 16),
            const Text("Nessun dato disponibile. Configura l'Ad Account ID."),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: context.spacing.iL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCampaignsSection(),
          const SizedBox(height: 24),
          if (_data!.metaInsights != null) _buildInsightsSection(),
        ],
      ),
    );
  }

  Widget _buildCampaignsSection() {
    final campaigns = _data!.metaCampaigns;
    final campaignList = campaigns['data'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: context.spacing.iL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Campagne Attive",
              style: context.text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (campaignList.isEmpty)
              const Center(child: Text("Nessuna campagna trovata"))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: campaignList.length,
                itemBuilder: (context, index) {
                  final campaign = campaignList[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: context.spacing.s),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: context.colors.infoColor,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(campaign['name'] ?? 'N/A'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.dashboardEtichettaId(
                              '${campaign['id'] ?? 'N/A'}',
                            ),
                          ),
                          Text(
                            context.l10n.dashboardEtichettaStatus(
                              '${campaign['status'] ?? 'N/A'}',
                            ),
                          ),
                        ],
                      ),
                      trailing: _buildCampaignStatusChip(campaign['status']),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignStatusChip(String? status) {
    Color color;
    IconData icon;

    switch (status?.toUpperCase()) {
      case 'ACTIVE':
        color = context.colors.successColor;
        icon = Icons.play_circle;
        break;
      case 'PAUSED':
        color = context.colors.warningColor;
        icon = Icons.pause_circle;
        break;
      default:
        color = context.colors.subtitleColor;
        icon = Icons.info;
    }

    return Chip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(status ?? 'N/A'),
      backgroundColor: color.withValues(alpha: 0.1),
    );
  }

  Widget _buildInsightsSection() {
    final insights = _data!.metaInsights;
    final insightsList = insights['data'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: context.spacing.iL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Insights & Metriche",
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (insightsList.isEmpty)
              const Center(child: Text("Nessun insight disponibile"))
            else
              _buildInsightsTable(insightsList),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsTable(List<dynamic> insights) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(context.l10n.dashboardCampagna)),
          DataColumn(label: Text(context.l10n.dashboardImpressioni)),
          DataColumn(label: Text(context.l10n.dashboardClick)),
          DataColumn(label: Text(context.l10n.dashboardSpesa)),
          DataColumn(label: Text(context.l10n.dashboardCpc)),
          DataColumn(label: Text(context.l10n.dashboardCtr)),
        ],
        rows: insights.map((insight) {
          return DataRow(
            cells: [
              DataCell(Text(insight['campaign_name']?.toString() ?? 'N/A')),
              DataCell(Text(insight['impressions']?.toString() ?? '0')),
              DataCell(Text(insight['clicks']?.toString() ?? '0')),
              DataCell(Text('€${insight['spend']?.toString() ?? '0'}')),
              DataCell(Text('€${insight['cpc']?.toString() ?? '0'}')),
              DataCell(Text('${insight['ctr']?.toString() ?? '0'}%')),
            ],
          );
        }).toList(),
      ),
    );
  }
}
