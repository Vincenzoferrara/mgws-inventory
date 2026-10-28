import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'class_loyalty_card.dart';
import 'loyalty_cards.code.dart';
import '../reuse_class/datagridview/datagridview_list.gui.dart';
import '../notification/notification_service.dart';
import '../theme/theme.dart';
import '../reuse_class/barcode/barcode_scanner.dart';
import '../l10n/extensions.dart';

class CartaFedeltaPage extends StatefulWidget {
  const CartaFedeltaPage({super.key});

  @override
  CartaFedeltaPageState createState() => CartaFedeltaPageState();
}

class CartaFedeltaPageState extends State<CartaFedeltaPage>
    with AutomaticKeepAliveClientMixin {
  final CartaFedeltaController _controller = CartaFedeltaController();
  late final DataGridListController<CartaFedeltaGlobal> _listController =
      DataGridListController<CartaFedeltaGlobal>(
        fields: CartaFedeltaGlobal.gridFields,
        idOf: _idOf,
        loadPage: _controller.caricaPagina,
        cacheKey: 'carte-fedelta',
        // La ricerca deve trovare anche i numeri di carta, che il server dei
        // clienti non conosce: si cerca sull'elenco completo.
        serverSearch: false,
      );

  static String _idOf(CartaFedeltaGlobal carta) => '${carta.customerId}';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _caricaStatistiche();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _caricaStatistiche() async {
    await _controller.caricaStatistiche();
    if (mounted) setState(() {});
  }

  /// Dopo una modifica di punti, livello o carta: lista e statistiche si
  /// ricaricano, e il dettaglio resta sullo stesso cliente con i dati nuovi.
  Future<void> _updateState() async {
    final selezionato = _listController.selected.value?.customerId;
    await Future.wait([
      _listController.reload(force: true),
      _caricaStatistiche(),
    ]);
    if (!mounted || selezionato == null) return;
    for (final carta in _listController.cache.items.isNotEmpty
        ? _listController.cache.items
        : _listController.visibleItems) {
      if (carta.customerId == selezionato) {
        _listController.select(carta);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necessario per AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    return Column(
      children: [
        // Le statistiche hanno testo chiaro: stanno sul gradiente
        // dell'intestazione, come prima della lista generica.
        if (_controller.statistiche != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  customColors.headerGradientStart,
                  customColors.headerGradientEnd,
                ],
              ),
            ),
            child: _buildStatisticheRapide(),
          ),
        Expanded(
          child: DataGridListView<CartaFedeltaGlobal>(
            controller: _listController,
            fields: CartaFedeltaGlobal.gridFields,
            idOf: _idOf,
            loadPage: _controller.caricaPagina,
            cacheKey: 'carte-fedelta',
            serverSearch: false,
            defaultColumns: const [
              'nome',
              'email',
              'numeroCarta',
              'livello',
              'punti',
            ],
            defaultMobileColumns: const ['nome', 'numeroCarta', 'punti'],
            onRefresh: _updateState,
            toolbarActions: [
              DataGridCommandIconButton(
                onPressed: () => _mostraDialogCercaCarta(context),
                icon: Icons.qr_code_scanner,
                tooltip: context.l10n.loyaltyScanCard,
                color: theme.colorScheme.primary,
              ),
            ],
            onRowSelected: (carta) => _controller.selezionaCarta(carta.toMap()),
            cellsOf: (context, carta) => <String, Widget>{
              'nome': Text(
                carta.nomeCompleto.isEmpty ? '-' : carta.nomeCompleto,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              'livello': carta.haCarta
                  ? DataGridStatusChip(
                      label: _tierName(carta.livello),
                      color: _getTierColor(carta.livello),
                    )
                  : Text(
                      '-',
                      style: TextStyle(color: customColors.subtitleColor),
                    ),
            },
            emptyDetailsIcon: Icons.card_membership_outlined,
            emptyDetailsTitle: (context) => context.l10n.loyaltySelectCard,
            detailsOf: (context, carta, inPage) {
              final dettagli = _buildDettagliCartaWidget(carta.toMap());
              return inPage
                  ? Scaffold(
                      appBar: AppBar(
                        title: Text(context.l10n.loyaltyCardDetails),
                      ),
                      body: dettagli,
                    )
                  : dettagli;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticheRapide() {
    final stats = _controller.statistiche!;
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            label: context.l10n.loyaltyTotalPoints,
            value: '${stats.pointsIssued ?? stats.pointsBalance}',
            icon: Icons.stars,
            color: colors.tierGold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatChip(
            label: context.l10n.loyaltyGold,
            value: '${stats.tierCount('gold')}',
            icon: Icons.workspace_premium,
            color: colors.tierGold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatChip(
            label: context.l10n.loyaltySilver,
            value: '${stats.tierCount('silver')}',
            icon: Icons.workspace_premium,
            color: colors.tierSilver,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.colors.onColoredSurface.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: context.colors.onColoredSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: context.colors.onColoredSurface.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Card per visualizzare una carta fedeltà (o l'assenza di carta)
  /// Widget dettagli carta selezionata
  Widget _buildDettagliCartaWidget(Map<String, dynamic> carta) {
    if (carta['has_card'] != true) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_membership_outlined,
              size: 64,
              color: context.colors.neutralColor,
            ),
            const SizedBox(height: 16),
            Text(
              '${carta['first_name']} ${carta['last_name']}'.trim(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              context.l10n.loyaltyNoCardAssociated,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.subtitleColor,
              ),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card visuale
          _buildVisualCard(carta),

          const SizedBox(height: 24),

          // Informazioni cliente
          _buildInfoSection(context.l10n.loyaltyCustomerInfo, [
            _buildInfoRow(
              context.l10n.commonName,
              '${carta['first_name']} ${carta['last_name']}',
            ),
            _buildInfoRow(
              context.l10n.loyaltyEmailLabel,
              carta['email'] ?? 'N/A',
            ),
            _buildInfoRow(
              context.l10n.loyaltyCustomerId,
              carta['customer_id'] != null ? '#${carta['customer_id']}' : 'N/A',
            ),
          ]),

          const SizedBox(height: 16),

          // Gestione punti
          _buildInfoSection(context.l10n.loyaltyPointsManagement, [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _mostraDialogGestionePunti(
                      context,
                      carta,
                      aggiungi: true,
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.loyaltyAdd),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: customColors.successColor,
                      foregroundColor: context.colors.onColoredSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _mostraDialogGestionePunti(
                      context,
                      carta,
                      aggiungi: false,
                    ),
                    icon: const Icon(Icons.remove),
                    label: Text(context.l10n.loyaltyRemove),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: customColors.errorColorStatus,
                      side: BorderSide(color: customColors.errorColorStatus),
                    ),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 16),

          // Gestione tier
          _buildInfoSection(context.l10n.loyaltyTierSection, [
            _buildTierSelector(carta),
          ]),

          const SizedBox(height: 16),

          // Azioni
          _buildInfoSection(context.l10n.loyaltyActions, [
            ElevatedButton.icon(
              onPressed: () => _mostraDialogStoricoPunti(context, carta),
              icon: const Icon(Icons.history),
              label: Text(context.l10n.loyaltyViewHistory),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: context.colors.onColoredSurface,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _confermaRimozioneCarta(context, carta),
              icon: const Icon(Icons.delete_outline),
              label: Text(context.l10n.loyaltyRemoveCard),
              style: OutlinedButton.styleFrom(
                foregroundColor: customColors.errorColorStatus,
                side: BorderSide(color: customColors.errorColorStatus),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  /// Card visuale della carta fedeltà
  Widget _buildVisualCard(Map<String, dynamic> carta) {
    final tier = carta['tier'] as String? ?? 'bronze';
    final punti = carta['points'] as int? ?? 0;
    final cardNumber = carta['card_number'] as String? ?? '';

    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getTierColor(tier),
            _getTierColor(tier).withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadowColor.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.card_membership,
                color: context.colors.onColoredSurface,
                size: 32,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.colors.onColoredSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _tierName(tier).toUpperCase(),
                  style: TextStyle(
                    color: context.colors.onColoredSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            cardNumber,
            style: TextStyle(
              color: context.colors.onColoredSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${carta['first_name']} ${carta['last_name']}'.toUpperCase(),
            style: TextStyle(
              color: context.colors.onColoredSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.loyaltyPointsLabel,
                    style: TextStyle(
                      color: context.colors.onColoredSurface.withValues(
                        alpha: 0.8,
                      ),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    '$punti',
                    style: TextStyle(
                      color: context.colors.onColoredSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.stars,
                color: context.colors.onColoredSurface,
                size: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sezione informazioni
  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  /// Riga informazione
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.colors.subtitleColor)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Selettore tier
  Widget _buildTierSelector(Map<String, dynamic> carta) {
    final tierCorrente = carta['tier'] as String? ?? 'bronze';
    final tiers = ['bronze', 'silver', 'gold', 'platinum'];

    return Wrap(
      spacing: 8,
      children: tiers.map((tier) {
        final isSelected = tier == tierCorrente;
        return ChoiceChip(
          label: Text(_tierName(tier)),
          selected: isSelected,
          selectedColor: _getTierColor(tier),
          backgroundColor: _getTierColor(tier).withValues(alpha: 0.3),
          labelStyle: TextStyle(
            color: isSelected
                ? context.colors.onColoredSurface
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (selected) async {
            if (selected && tier != tierCorrente) {
              final success = await _controller.aggiornaTier(
                customerId: carta['customer_id'],
                numeroCarta: carta['card_number'],
                nuovoTier: tier,
              );

              if (success && mounted) {
                NotificationService.instance.messageBar(
                  'successo',
                  'carta_fedelta',
                  context.l10n.loyaltyTierUpdated,
                );
                _updateState();
              }
            }
          },
        );
      }).toList(),
    );
  }

  /// Empty state
  Future<void> _mostraDialogCercaCarta(BuildContext context) async {
    final controller = TextEditingController();
    // Il contesto del dialog viene smontato al pop: le stringhe dei messaggi di
    // notifica vanno quindi lette dal contesto della pagina, non da quello del dialog.
    final cartaTrovata = context.l10n.loyaltyCardFound;
    final cartaNonTrovata = context.l10n.loyaltyCardNotFound;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.loyaltySearchCardTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: context.l10n.loyaltyCardNumberLabel,
                hintText: context.l10n.loyaltyEnterOrScan,
                prefixIcon: const Icon(Icons.card_membership),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final scanned = await showBarcodeScanner(context);
                    if (scanned != null) {
                      controller.text = scanned;
                    }
                  },
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final numeroCarta = controller.text.trim();
              if (numeroCarta.isEmpty) return;

              Navigator.pop(context);

              final carta = await _controller.cercaCartaPerNumero(numeroCarta);

              if (carta != null && mounted) {
                final trovata = CartaFedeltaGlobal.daMappa(carta);
                _controller.selezionaCarta(carta);
                // La ricerca per numero mostra la riga anche su telefono, dove
                // il dettaglio non ha un pannello accanto alla lista.
                if (trovata.haCarta) {
                  _listController.setSearch(trovata.numeroCarta!);
                }
                _listController.select(trovata);

                if (mounted) {
                  NotificationService.instance.messageBar(
                    'successo',
                    'carta_fedelta',
                    cartaTrovata,
                  );
                }
              } else {
                if (mounted) {
                  NotificationService.instance.messageBar(
                    'errore',
                    'carta_fedelta',
                    cartaNonTrovata,
                  );
                }
              }
            },
            child: Text(context.l10n.commonSearch),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  /// Dialog gestione punti
  Future<void> _mostraDialogGestionePunti(
    BuildContext context,
    Map<String, dynamic> carta, {
    required bool aggiungi,
  }) async {
    final puntiController = TextEditingController();
    final noteController = TextEditingController();
    // Vedi _mostraDialogCercaCarta: le stringhe delle notifiche si leggono dal
    // contesto della pagina, perche il contesto del dialog viene smontato.
    final puntiOk = context.l10n.loyaltyPointsAdded;
    final puntiKo = context.l10n.loyaltyPointsRemoved;
    final notaAggiunta = context.l10n.loyaltyNoteAddedManually;
    final notaSottratta = context.l10n.loyaltyNoteRemovedManually;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          aggiungi
              ? context.l10n.loyaltyAddPointsTitle
              : context.l10n.loyaltyRemovePointsTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: puntiController,
              decoration: InputDecoration(
                labelText: context.l10n.loyaltyPointsField,
                prefixIcon: const Icon(Icons.stars),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: context.l10n.loyaltyNotesOptional,
                prefixIcon: const Icon(Icons.note),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final punti = int.tryParse(puntiController.text) ?? 0;
              if (punti <= 0) return;

              Navigator.pop(context);

              final success = aggiungi
                  ? await _controller.aggiungiPunti(
                      customerId: carta['customer_id'],
                      punti: punti,
                      note: noteController.text.trim().isNotEmpty
                          ? noteController.text.trim()
                          : notaAggiunta,
                    )
                  : await _controller.sottraiPunti(
                      customerId: carta['customer_id'],
                      punti: punti,
                      note: noteController.text.trim().isNotEmpty
                          ? noteController.text.trim()
                          : notaSottratta,
                    );

              if (success && mounted) {
                NotificationService.instance.messageBar(
                  'successo',
                  'carta_fedelta',
                  aggiungi ? puntiOk : puntiKo,
                );
                _updateState();
              }
            },
            child: Text(
              aggiungi ? context.l10n.loyaltyAdd : context.l10n.loyaltyRemove,
            ),
          ),
        ],
      ),
    );

    puntiController.dispose();
    noteController.dispose();
  }

  /// Dialog storico punti
  Future<void> _mostraDialogStoricoPunti(
    BuildContext context,
    Map<String, dynamic> carta,
  ) async {
    final storico = await _controller.getStoricoPunti(carta['customer_id']);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.loyaltyHistoryTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: storico.isEmpty
              ? Center(child: Text(context.l10n.loyaltyNoHistory))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: storico.length,
                  itemBuilder: (context, index) {
                    final entry = storico[index];
                    final amount = entry['amount'] as int? ?? 0;
                    final isPositive = amount >= 0;

                    return ListTile(
                      leading: Icon(
                        isPositive ? Icons.add_circle : Icons.remove_circle,
                        color: isPositive
                            ? context.colors.successColor
                            : context.colors.errorColorStatus,
                      ),
                      title: Text(entry['note'] ?? 'N/A'),
                      subtitle: Text(entry['date'] ?? ''),
                      trailing: Text(
                        '${isPositive ? '+' : ''}$amount',
                        style: TextStyle(
                          color: isPositive
                              ? context.colors.successColor
                              : context.colors.errorColorStatus,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
  }

  /// Conferma rimozione carta
  Future<void> _confermaRimozioneCarta(
    BuildContext context,
    Map<String, dynamic> carta,
  ) async {
    // Vedi _mostraDialogCercaCarta: le stringhe delle notifiche si leggono dal
    // contesto della pagina, perche il contesto del dialog viene smontato.
    final cartaRimossa = context.l10n.loyaltyCardRemoved;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.loyaltyRemoveConfirmTitle),
        content: Text(context.l10n.loyaltyRemoveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.errorColorStatus,
              foregroundColor: context.colors.onColoredSurface,
            ),
            child: Text(context.l10n.loyaltyRemove),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _controller.rimuoviCarta(carta['customer_id']);

      if (success && mounted) {
        NotificationService.instance.messageBar(
          'successo',
          'carta_fedelta',
          cartaRimossa,
        );
        _updateState();
      }
    }
  }

  // =======================================================
  // == HELPER METHODS                                    ==
  // =======================================================

  /// Nome visualizzato del tier, tradotto.
  ///
  /// Il controller conosce solo i codici tier (`bronze`, `gold`, ...): la parte
  /// leggibile dipende dalla lingua e quindi vive qui, non nel layer dati.
  String _tierName(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return context.l10n.loyaltyTierPlatinum;
      case 'gold':
        return context.l10n.loyaltyTierGold;
      case 'silver':
        return context.l10n.loyaltyTierSilver;
      case 'bronze':
      default:
        return context.l10n.loyaltyTierBronze;
    }
  }

  Color _getTierColor(String tier) {
    final colors = context.colors;
    switch (tier.toLowerCase()) {
      case 'platinum':
        return colors.tierPlatinum;
      case 'gold':
        return colors.tierGold;
      case 'silver':
        return colors.tierSilver;
      case 'bronze':
      default:
        return colors.tierBronze;
    }
  }
}
