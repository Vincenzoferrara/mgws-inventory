// TikTok Ads Detail - Finestra dettagliata per TikTok Ads

import 'package:flutter/material.dart';
import 'ads_dashboard.code.dart';
import '../theme/theme.dart';
import '../l10n/extensions.dart';

/// Finestra dettagliata per visualizzare campagne e report TikTok Ads
class TikTokAdsDetailPage extends StatefulWidget {
  final AdsPlatformService adsService;
  final String? advertiserId;

  const TikTokAdsDetailPage({
    super.key,
    required this.adsService,
    this.advertiserId,
  });

  @override
  State<TikTokAdsDetailPage> createState() => _TikTokAdsDetailPageState();
}

class _TikTokAdsDetailPageState extends State<TikTokAdsDetailPage> {
  AdsPlatformData? _data;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!widget.adsService.isConnected("tiktok")) {
      setState(() {
        _errorMessage =
            "Non sei connesso a TikTok Ads. Effettua il login dalla dashboard principale.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await widget.adsService.fetchAllData(
        tiktokAdvertiserId: widget.advertiserId,
      );

      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Errore caricamento dati TikTok Ads: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.tiktok, size: 28),
            SizedBox(width: 8),
            Text("TikTok Ads - Dettagli"),
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

    if (_data == null || _data!.tiktokCampaigns == null) {
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
            const Text("Nessun dato disponibile. Configura l'Advertiser ID."),
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
          if (_data!.tiktokReports != null) _buildReportsSection(),
        ],
      ),
    );
  }

  Widget _buildCampaignsSection() {
    final campaigns = _data!.tiktokCampaigns;
    final campaignList = campaigns['data'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: context.spacing.iL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Campagne TikTok",
              style: context.text.titleLarge?.copyWith(
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
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: context.colors.neutralColor,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        campaign['campaign_name'] ?? 'N/A',
                        style: context.text.titleMedium,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.dashboardEtichettaId(
                              '${campaign['campaign_id'] ?? 'N/A'}',
                            ),
                          ),
                          Text(
                            'Obiettivo: ${campaign['objective_type'] ?? 'N/A'}',
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
      case 'ENABLE':
      case 'ACTIVE':
        color = context.colors.successColor;
        icon = Icons.play_circle;
        break;
      case 'DISABLE':
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
      label: Text(status ?? 'N/A', style: context.text.bodyMedium),
      backgroundColor: color.withValues(alpha: 0.1),
    );
  }

  Widget _buildReportsSection() {
    final reports = _data!.tiktokReports;
    final reportsList = reports['data'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: context.spacing.iL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Report & Metriche (Ultimi 30 giorni)",
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (reportsList.isEmpty)
              const Center(child: Text("Nessun report disponibile"))
            else
              _buildReportsGrid(reportsList),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsGrid(List<dynamic> reports) {
    // Calcola totali
    double totalSpend = 0;
    int totalImpressions = 0;
    int totalClicks = 0;
    int totalConversions = 0;

    for (var report in reports) {
      totalSpend += double.tryParse(report['spend']?.toString() ?? '0') ?? 0;
      totalImpressions +=
          int.tryParse(report['impressions']?.toString() ?? '0') ?? 0;
      totalClicks += int.tryParse(report['clicks']?.toString() ?? '0') ?? 0;
      totalConversions +=
          int.tryParse(report['conversions']?.toString() ?? '0') ?? 0;
    }

    final ctr = totalImpressions > 0
        ? (totalClicks / totalImpressions) * 100
        : 0;
    final cpc = totalClicks > 0 ? totalSpend / totalClicks : 0;

    final colors = context.colors;
    return Column(
      children: [
        Wrap(
          spacing: context.spacing.l,
          runSpacing: context.spacing.l,
          children: [
            _buildMetricCard(
              "Spesa Totale",
              "€${totalSpend.toStringAsFixed(2)}",
              Icons.euro,
              colors.errorColorStatus,
            ),
            _buildMetricCard(
              "Impressioni",
              totalImpressions.toString(),
              Icons.visibility,
              colors.infoColor,
            ),
            _buildMetricCard(
              "Click",
              totalClicks.toString(),
              Icons.touch_app,
              colors.successColor,
            ),
            _buildMetricCard(
              "Conversioni",
              totalConversions.toString(),
              Icons.shopping_cart,
              colors.warningColor,
            ),
            _buildMetricCard(
              "CTR",
              "${ctr.toStringAsFixed(2)}%",
              Icons.percent,
              context.colors.infoColor,
            ),
            _buildMetricCard(
              "CPC",
              "€${cpc.toStringAsFixed(2)}",
              Icons.monetization_on,
              context.colors.successColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 150,
      padding: context.spacing.iL,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: context.shapes.m,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.subtitleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Estensione per icona TikTok
extension TikTokIcon on Icons {
  static const IconData tiktok = IconData(0xe900, fontFamily: 'MaterialIcons');
}
