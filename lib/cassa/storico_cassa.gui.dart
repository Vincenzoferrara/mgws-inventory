import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import 'cassa.code.dart';
import 'class_scontrino.dart';
import 'storico_cassa.code.dart';
import '../traduzioni/estensioni.dart';

/// Voce "Storico cassa" dentro il modulo Cassa.
///
/// Storico scontrini POS separato dagli ordini WooCommerce: mostra solo il
/// canale `pos`, con righe, pagamenti, operatore, cassa, totali, resi
/// collegati e riferimento all'ordine creato da MGWS. I resi partono sempre
/// da una riga venduta con controllo sul residuo rendibile.
class StoricoCassaPage extends StatefulWidget {
  final CassaController controller;
  final VoidCallback onVaiAllaVendita;

  const StoricoCassaPage({
    super.key,
    required this.controller,
    required this.onVaiAllaVendita,
  });

  @override
  State<StoricoCassaPage> createState() => _StoricoCassaPageState();
}

class _StoricoCassaPageState extends State<StoricoCassaPage> {
  final _searchController = TextEditingController();
  final _cassaFiltroController = TextEditingController();
  String? _metodoFiltro;
  bool _soloResi = false;
  bool _loading = true;
  String _query = '';

  /// Receipts currently shown, loaded from the server.
  List<Scontrino> _receipts = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cassaFiltroController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await widget.controller.storicoStore.init();
    final receipts = await _filtered();
    if (!mounted) return;
    setState(() {
      _receipts = receipts;
      _loading = false;
    });
  }

  /// Loads the history from the server, keeping the local store as fallback.
  Future<List<Scontrino>> _filtered() async {
    return widget.controller.storicoStore.filter(
      queryCliente: _query,
      cassaNome: _cassaFiltroController.text.trim().isEmpty
          ? null
          : _cassaFiltroController.text.trim(),
      metodoPagamento: _metodoFiltro,
      soloResi: _soloResi ? true : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final receipts = _receipts;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: context.l10n.cassaCercaHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cassaFiltroController,
                      decoration: InputDecoration(
                        labelText: context.l10n.cassaFiltroCassaOpzionale,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _metodoFiltro,
                      decoration: InputDecoration(
                        labelText: context.l10n.cassaMetodo,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(context.l10n.cassaTutti),
                        ),
                        DropdownMenuItem(
                          value: 'contanti',
                          child: Text(context.l10n.cassaContanti),
                        ),
                        DropdownMenuItem(
                          value: 'carta',
                          child: Text(context.l10n.cassaCarta),
                        ),
                        DropdownMenuItem(
                          value: 'bancomat',
                          child: Text(context.l10n.cassaBancomat),
                        ),
                      ],
                      onChanged: (v) => setState(() => _metodoFiltro = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(context.l10n.cassaResi),
                    selected: _soloResi,
                    onSelected: (v) => setState(() => _soloResi = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${receipts.length} scontrini POS (canale pos, separati dagli ordini Woo)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.cassaAggiorna),
                  ),
                  TextButton.icon(
                    onPressed: () => _dialogChiusura(context),
                    icon: const Icon(Icons.lock_clock),
                    label: Text(context.l10n.cassaChiusura),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: receipts.isEmpty
              ? Center(
                  child: Text(
                    'Nessuno scontrino POS archiviato con questi filtri.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: receipts.length,
                  itemBuilder: (context, i) =>
                      _cardScontrino(context, receipts[i]),
                ),
        ),
      ],
    );
  }

  Widget _cardScontrino(BuildContext context, Scontrino s) {
    final theme = Theme.of(context);
    final custom = theme.extension<AppColorExtension>()!;
    final numero = s.numeroProgressivo != null
        ? '#${s.numeroProgressivo}'
        : '#${s.id.substring(0, s.id.length > 6 ? 6 : s.id.length)}';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          s.stato == 'annullato'
              ? Icons.block
              : (s.hasResi ? Icons.assignment_return : Icons.receipt_long),
          color: s.stato == 'annullato'
              ? theme.disabledColor
              : s.totale < 0
              ? custom.errorColorStatus
              : custom.successColor,
        ),
        title: Text(
          '$numero - €${s.totale.toStringAsFixed(2)} - ${s.metodoPagamento}'
          '${s.stato == 'annullato' ? ' · ANNULLATO' : ''}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${s.data} · ${s.operatoreLabel}'
          '${s.cassaNome != null ? ' · ${s.cassaNome}' : ''}'
          '${s.wooOrderId != null ? ' · ordine ${s.wooOrderId}' : ''}'
          '${s.clienteNome != null ? ' · ${s.clienteNome}' : ''}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _dialogDettaglio(context, s),
      ),
    );
  }

  Future<void> _dialogDettaglio(BuildContext context, Scontrino s) async {
    final theme = Theme.of(context);
    final rendibili = widget.controller.storicoStore.righeRendibili(s.id);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Scontrino ${s.numeroProgressivo != null ? '#${s.numeroProgressivo}' : s.id}',
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'POS · ${s.data} · ${s.metodoPagamento} · €${s.totale.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall,
                ),
                if (s.stato == 'annullato')
                  Text(
                    'Scontrino annullato: escluso da totali e resi.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  'Operatore: ${s.operatoreLabel}'
                  '${s.cassaNome != null ? ' · Cassa ${s.cassaNome}' : ''}'
                  '${s.sede != null ? ' · ${s.sede}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
                if (s.wooOrderId != null)
                  Text(
                    'Ordine Woo/MGWS collegato: ${s.wooOrderId} (solo riferimento, ciclo separato)',
                    style: theme.textTheme.bodySmall,
                  ),
                const Divider(),
                Text(
                  'Righe vendute e residuo rendibile',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (rendibili.isEmpty)
                  Text(context.l10n.cassaNessunaRigaVendita),
                for (final r in rendibili)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${r.nome} - €${r.prezzoUnitario.toStringAsFixed(2)}',
                    ),
                    subtitle: Text(
                      'Barcode interno ${r.barcodeInterno} · venduti ${r.quantitaVenduta} · '
                      'gia resi ${r.quantitaGiaResa} · '
                      'rendibili ${r.quantitaRendibile}',
                    ),
                    trailing: r.isEsaurita
                        ? Chip(label: Text(context.l10n.cassaEsaurita))
                        : Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: s.stato == 'annullato'
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        _dialogNuovoReso(context, s.id, r);
                                      },
                                child: Text(context.l10n.cassaReso),
                              ),
                              TextButton(
                                onPressed: s.stato == 'annullato'
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        _dialogNuovoReso(
                                          context,
                                          s.id,
                                          r,
                                          cambio: true,
                                        );
                                      },
                                child: Text(context.l10n.cassaCambio),
                              ),
                            ],
                          ),
                  ),
                const Divider(),
                Text(
                  'Righe registrate',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final riga in s.righe)
                  Text(
                    '${riga.isReso ? '[RESO] ' : ''}${riga.nomeCompleto} x${riga.quantita} '
                    '- €${riga.subtotale.toStringAsFixed(2)}'
                    '${riga.motivoReso != null ? ' (${riga.motivoReso})' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (s.rettifiche.isNotEmpty) ...[
                  const Divider(),
                  Text(
                    'Rettifiche',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final nota in s.rettifiche)
                    Text('• $nota', style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _dialogRettificaScontrino(context, s);
            },
            child: Text(context.l10n.cassaRettifica),
          ),
          TextButton(
            onPressed: s.stato == 'annullato'
                ? null
                : () async {
                    Navigator.pop(context);
                    await _dialogAnnullaScontrino(context, s);
                  },
            child: Text(context.l10n.commonAnnulla),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _dialogNuovoReso(
    BuildContext context,
    String scontrinoId,
    RigaRendibile riga, {
    bool cambio = false,
  }) async {
    final qtyController = TextEditingController(text: '1');
    final motivoController = TextEditingController();
    String esito = 'reintegro';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
          context.l10n.cassaTitoloVincolato(
            cambio ? context.l10n.cassaCambio : context.l10n.cassaReso,
            riga.nome,
          ),
        ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rendibili: ${riga.quantitaRendibile} '
                  '(venduti ${riga.quantitaVenduta}, gia resi ${riga.quantitaGiaResa}). '
                  'Il prezzo resta quello pagato: €${riga.prezzoUnitario.toStringAsFixed(2)}.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: context.l10n.cassaQuantitaDaRendere,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motivoController,
                  decoration: InputDecoration(
                    labelText: context.l10n.cassaMotivoReso,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: esito,
                  decoration: InputDecoration(
                    labelText: context.l10n.cassaEsitoMerce,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'reintegro',
                      child: Text(context.l10n.cassaReintegroInMagazzino),
                    ),
                    DropdownMenuItem(
                      value: 'difettoso',
                      child: Text(context.l10n.cassaDifettosoNonVendibile),
                    ),
                    DropdownMenuItem(
                      value: 'buono',
                      child: Text(context.l10n.cassaBuonoCreditoCliente),
                    ),
                    DropdownMenuItem(
                      value: 'sostituzione',
                      child: Text(context.l10n.cassaSostituzione),
                    ),
                    DropdownMenuItem(
                      value: 'rimborso',
                      child: Text(context.l10n.cassaRimborso),
                    ),
                  ],
                  onChanged: (v) => setState(() => esito = v ?? 'reintegro'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.commonAnnulla),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(cambio
                  ? context.l10n.cassaPreparaCambio
                  : context.l10n.cassaPreparaReso),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final qty = int.tryParse(qtyController.text.trim()) ?? 0;
    final errore = await widget.controller.preparaResoVincolato(
      scontrinoOrigineId: scontrinoId,
      chiaveRiga: riga.chiaveRiga,
      quantita: qty,
      motivo: motivoController.text,
      esitoMerce: esito,
      preparaCambio: cambio,
    );
    if (!context.mounted) return;
    if (errore != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cambio
              ? 'Cambio preparato: aggiungi il prodotto sostitutivo e completa il checkout.'
              : 'Reso preparato nel carrello: completa il checkout per registrarlo.',
        ),
      ),
    );
    widget.onVaiAllaVendita();
  }

  Future<void> _dialogAnnullaScontrino(
    BuildContext context,
    Scontrino s,
  ) async {
    final controller = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.l10n.cassaAnnullaScontrino('${s.numeroProgressivo ?? s.id}'),
        ),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: context.l10n.cassaMotivoAnnullo,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonAnnulla),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.cassaConfermaAnnullo),
          ),
        ],
      ),
    );
    controller.dispose();
    if (motivo == null) return;
    final esito = await widget.controller.storicoStore.cancelReceipt(
      receiptId: s.id,
      reason: motivo,
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(esito.ok ? 'Scontrino annullato.' : esito.errore!),
      ),
    );
  }

  Future<void> _dialogRettificaScontrino(
    BuildContext context,
    Scontrino s,
  ) async {
    final controller = TextEditingController();
    final nota = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.l10n.cassaRettificaScontrino('${s.numeroProgressivo ?? s.id}'),
        ),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: context.l10n.cassaNotaRettificaAppendOnly,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonAnnulla),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.cassaSalvaRettifica),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nota == null) return;
    final esito = await widget.controller.storicoStore
        .aggiungiRettificaScontrino(scontrinoId: s.id, nota: nota);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(esito.ok ? 'Rettifica salvata.' : esito.errore!)),
    );
  }

  Future<void> _dialogChiusura(BuildContext context) async {
    final store = widget.controller.storicoStore;
    await store.init();
    final turno = widget.controller.turnoCorrente;
    if (!context.mounted) return;
    if (turno == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cassaNessunTurnoAperto)),
      );
      return;
    }
    final totali = store.totaliGiornata(turno.giornataId, turnoId: turno.id);
    final esistente = store.cercaChiusuraTurno(turno.id);
    if (esistente != null) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.cassaTurnoGiaChiuso),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    context.l10n.cassaEtichettaGiornata('${esistente.giornataId}'),
                  ),
                if (esistente.turnoId != null)
                  Text(
                    context.l10n.cassaEtichettaTurno('${esistente.turnoId}'),
                  ),
                Text(
                  'Contante atteso €${esistente.contanteAtteso.toStringAsFixed(2)} · '
                  'contato €${esistente.contanteContato.toStringAsFixed(2)} · '
                  'differenza €${esistente.differenzaContanti.toStringAsFixed(2)}',
                ),
                Text(
                  'Carta attesa €${esistente.cartaAttesa.toStringAsFixed(2)} · '
                  'contattata €${esistente.cartaContato.toStringAsFixed(2)} · '
                  'differenza €${esistente.differenzaCarta.toStringAsFixed(2)}',
                ),
                if ((esistente.causaleDifferenza ?? '').isNotEmpty)
                  Text(
                    context.l10n.cassaEtichettaCausale(
                      '${esistente.causaleDifferenza}',
                    ),
                  ),
                if ((esistente.note ?? '').isNotEmpty)
                  Text(context.l10n.cassaEtichettaNote('${esistente.note}')),
                for (final r in esistente.rettifiche) Text('- $r'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cassaChiudi),
            ),
            TextButton(
              onPressed: () async {
                final notaController = TextEditingController();
                final nota = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.l10n.cassaNotaDiRettifica),
                    content: TextField(
                      controller: notaController,
                      decoration: InputDecoration(
                        labelText: context.l10n.cassaRettificaNonModificaChiusura,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.l10n.commonAnnulla),
                      ),
                      FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, notaController.text),
                        child: Text(context.l10n.cassaSalva),
                      ),
                    ],
                  ),
                );
                if (nota != null && nota.trim().isNotEmpty) {
                  await store.aggiungiRettifica(esistente.id, nota.trim());
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(context.l10n.cassaAggiungiRettifica),
            ),
          ],
        ),
      );
      return;
    }

    final contantiController = TextEditingController();
    final cartaController = TextEditingController();
    final causaleController = TextEditingController();
    final noteController = TextEditingController();
    final registrata = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.cassaChiusuraTurno('${turno.id}')),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incassi turno - contanti €${(totali['contanti'] ?? 0).toStringAsFixed(2)} · '
                  'carta €${(totali['carta'] ?? 0).toStringAsFixed(2)} · '
                  'altri €${(totali['altri'] ?? 0).toStringAsFixed(2)} · '
                  'rimborsi €${(totali['rimborsi'] ?? 0).toStringAsFixed(2)}',
                ),
                Text(
                  'Turno: ${turno.id} · Operatore: ${turno.operatoreLabel} · '
                  'Fondo iniziale €${turno.fondoIniziale.toStringAsFixed(2)}.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contantiController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.cassaContantiContati,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cartaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.cassaCartaPosContato,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: causaleController,
                  decoration: InputDecoration(
                    labelText: context.l10n.cassaCausaleDifferenzaObbligatoria,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: context.l10n.cassaNote,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonAnnulla),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.cassaRegistraChiusura),
          ),
        ],
      ),
    );
    if (registrata != true || !context.mounted) return;
    double parse(String v) =>
        double.tryParse(v.replaceAll(',', '.').trim()) ?? 0;
    final esito = await widget.controller.chiudiTurno(
      contanteContato: parse(contantiController.text),
      cartaContato: parse(cartaController.text),
      causaleDifferenza: causaleController.text.trim().isEmpty
          ? null
          : causaleController.text.trim(),
      note: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
    );
    if (!context.mounted) return;
    final chiusura = store.cercaChiusuraTurno(turno.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          esito.ok
              ? 'Chiusura registrata. Differenza contanti €${(chiusura?.differenzaContanti ?? 0).toStringAsFixed(2)}, carta €${(chiusura?.differenzaCarta ?? 0).toStringAsFixed(2)}.'
              : (esito.errore ?? 'Chiusura non registrata.'),
        ),
      ),
    );
  }
}
