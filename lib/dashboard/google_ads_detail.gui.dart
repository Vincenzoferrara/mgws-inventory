// Google Ads Detail - Finestra dettagliata per Google Ads

import 'package:flutter/material.dart';
import '../theme/theme.dart';
import 'ads_dashboard.code.dart';

/// Finestra dettagliata per visualizzare campagne Google Ads
class GoogleAdsDetailPage extends StatefulWidget {
  final AdsPlatformService adsService;
  final String? customerId;

  const GoogleAdsDetailPage({
    super.key,
    required this.adsService,
    this.customerId,
  });

  @override
  State<GoogleAdsDetailPage> createState() => _GoogleAdsDetailPageState();
}

class _GoogleAdsDetailPageState extends State<GoogleAdsDetailPage> {
  AdsPlatformData? _data;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!widget.adsService.isConnected("google")) {
      setState(() {
        _errorMessage =
            "Non sei connesso a Google Ads. Effettua il login dalla dashboard principale.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await widget.adsService.fetchAllData(
        googleCustomerId: widget.customerId,
      );

      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Errore caricamento dati Google Ads: $e";
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
            Icon(
              Icons.g_mobiledata,
              color: context.colors.errorColorStatus,
              size: 32,
            ),
            const SizedBox(width: 8),
            const Text("Google Ads - Dettagli"),
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
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text("Riprova")),
          ],
        ),
      );
    }

    if (_data == null || _data!.googleCampaigns == null) {
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
            const Text("Nessun dato disponibile. Configura il Customer ID."),
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
          _buildMetricsOverview(),
        ],
      ),
    );
  }

  Widget _buildCampaignsSection() {
    return Card(
      child: Padding(
        padding: context.spacing.iL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Campagne Google Ads",
              style: context.text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.construction,
                    size: 48,
                    color: context.colors.warningColor,
                  ),
                  const SizedBox(height: 8),
                  const Text("Dati campagne Google Ads in arrivo"),
                  const SizedBox(height: 4),
                  Text(
                    "Implementazione query Google Ads API in corso",
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsOverview() {
    final colors = context.colors;
    return Card(
      child: Padding(
        padding: context.spacing.iL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Metriche Prestazioni",
              style: context.text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildMetricCard(
                  "Impressioni",
                  "0",
                  Icons.visibility,
                  colors.infoColor,
                ),
                _buildMetricCard(
                  "Click",
                  "0",
                  Icons.touch_app,
                  colors.successColor,
                ),
                _buildMetricCard(
                  "Costo",
                  "€0.00",
                  Icons.euro,
                  colors.errorColorStatus,
                ),
                _buildMetricCard(
                  "Conversioni",
                  "0",
                  Icons.shopping_cart,
                  colors.warningColor,
                ),
              ],
            ),
          ],
        ),
      ),
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
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
