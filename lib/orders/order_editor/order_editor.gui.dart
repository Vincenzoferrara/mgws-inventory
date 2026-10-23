import 'package:flutter/material.dart';
import '../order_list/order_list.code.dart';
import '../class_orders.dart';
import '../../notification/notification_service.dart';
import '../../l10n/extensions.dart';
import '../../theme/theme.dart';

/// Pagina per la creazione di un nuovo ordine
class OrdiniCreaPage extends StatefulWidget {
  final OrdiniGestioneController controller;

  const OrdiniCreaPage({super.key, required this.controller});

  @override
  State<OrdiniCreaPage> createState() => _OrdiniCreaPageState();
}

class _OrdiniCreaPageState extends State<OrdiniCreaPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers per i campi del form
  final _emailController = TextEditingController();
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _indirizzoController = TextEditingController();
  final _indirizzo2Controller = TextEditingController();
  final _cittaController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _capController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _aziendaController = TextEditingController();

  OrdineStatus _statoSelezionato = OrdineStatus.pending;
  String _metodoPagamento = 'cod';
  bool _isCreating = false;
  bool _copiaIndirizzo = true;

  @override
  void dispose() {
    _emailController.dispose();
    _nomeController.dispose();
    _cognomeController.dispose();
    _indirizzoController.dispose();
    _indirizzo2Controller.dispose();
    _cittaController.dispose();
    _provinciaController.dispose();
    _capController.dispose();
    _telefonoController.dispose();
    _aziendaController.dispose();
    super.dispose();
  }

  Future<void> _creaOrdine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final billing = IndirizzoBilling(
        firstName: _nomeController.text,
        lastName: _cognomeController.text,
        email: _emailController.text,
        phone: _telefonoController.text,
        address1: _indirizzoController.text,
        address2: _indirizzo2Controller.text.isEmpty
            ? null
            : _indirizzo2Controller.text,
        city: _cittaController.text,
        state: _provinciaController.text,
        postcode: _capController.text,
        country: 'IT',
        company: _aziendaController.text.isEmpty
            ? null
            : _aziendaController.text,
      );

      final shipping = _copiaIndirizzo
          ? IndirizzoShipping(
              firstName: _nomeController.text,
              lastName: _cognomeController.text,
              address1: _indirizzoController.text,
              address2: _indirizzo2Controller.text.isEmpty
                  ? null
                  : _indirizzo2Controller.text,
              city: _cittaController.text,
              state: _provinciaController.text,
              postcode: _capController.text,
              country: 'IT',
              company: _aziendaController.text.isEmpty
                  ? null
                  : _aziendaController.text,
            )
          : null;

      final nuovoOrdine = OrdiniGlobal(
        id: 0,
        status: _statoSelezionato,
        billing: billing,
        shipping: shipping,
        paymentMethod: _metodoPagamento,
        paymentMethodTitle: _getMetodoPagamentoTitolo(_metodoPagamento),
        lineItems: [], // Ordine vuoto, i prodotti verranno aggiunti dopo
      );

      final ordine = await widget.controller.creaOrdine(nuovoOrdine);

      if (mounted) {
        if (ordine != null) {
          Navigator.pop(context, ordine);
          NotificationService.instance.messageBar(
            'successo',
            'ordini_crea',
            context.l10n.ordersCreated('${ordine.number}'),
          );
        } else {
          NotificationService.instance.messageBar(
            'errore',
            'ordini_crea',
            context.l10n.ordersCreateError,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  String _getMetodoPagamentoTitolo(String metodo) {
    switch (metodo) {
      case 'cod':
        return context.l10n.ordiniMetodoContrassegno;
      case 'bacs':
        return context.l10n.ordiniMetodoBonifico;
      case 'cheque':
        return context.l10n.ordiniMetodoAssegno;
      case 'paypal':
        return context.l10n.ordiniPayPal;
      default:
        return context.l10n.ordiniMetodoAltro;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.ordiniCreaNuovoOrdine),
        actions: [
          if (_isCreating)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.colors.onColoredSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stato ordine
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.ordersInfoTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<OrdineStatus>(
                      initialValue: _statoSelezionato,
                      decoration: InputDecoration(
                        labelText: context.l10n.ordiniStatoIniziale,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      items: widget.controller.getStatiDisponibili().map((
                        status,
                      ) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(
                            widget.controller.getTestoStato(
                              context.l10n,
                              status,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _statoSelezionato = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _metodoPagamento,
                      decoration: InputDecoration(
                        labelText: context.l10n.ordiniEtichettaMetodoPagamento,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'cod',
                          child: Text(context.l10n.ordiniMetodoContrassegno),
                        ),
                        DropdownMenuItem(
                          value: 'bacs',
                          child: Text(context.l10n.ordiniMetodoBonifico),
                        ),
                        DropdownMenuItem(
                          value: 'cheque',
                          child: Text(context.l10n.ordiniMetodoAssegno),
                        ),
                        DropdownMenuItem(
                          value: 'paypal',
                          child: Text(context.l10n.ordiniPayPal),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _metodoPagamento = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dati cliente
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.ordersCustomerData,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: context.l10n.ordiniCampoEmail,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.l10n.commonFieldRequired;
                        }
                        if (!value.contains('@')) {
                          return context.l10n.commonInvalidEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nomeController,
                            decoration: InputDecoration(
                              labelText: context.l10n.ordiniCampoNome,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) => value?.isEmpty ?? true
                                ? context.l10n.commonFieldRequired
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _cognomeController,
                            decoration: InputDecoration(
                              labelText: context.l10n.ordiniCampoCognome,
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => value?.isEmpty ?? true
                                ? context.l10n.commonFieldRequired
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telefonoController,
                      decoration: InputDecoration(
                        labelText: context.l10n.ordiniCampoTelefono,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _aziendaController,
                      decoration: InputDecoration(
                        labelText: context.l10n.ordiniAziendaFacoltativa,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Indirizzo di fatturazione
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.ordersBillingAddress,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Checkbox(
                          value: _copiaIndirizzo,
                          onChanged: (value) {
                            setState(() => _copiaIndirizzo = value ?? true);
                          },
                        ),
                        Text(context.l10n.ordiniCopiaPerSpedizione),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _indirizzoController,
                      decoration: InputDecoration(
                        labelText: context.l10n.ordiniCampoIndirizzo,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (value) => value?.isEmpty ?? true
                          ? context.l10n.commonFieldRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _indirizzo2Controller,
                      decoration: InputDecoration(
                        labelText: context.l10n.ordiniCampoIndirizzo2,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cittaController,
                            decoration: InputDecoration(
                              labelText: context.l10n.ordiniCampoCitta,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_city),
                            ),
                            validator: (value) => value?.isEmpty ?? true
                                ? context.l10n.commonFieldRequired
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _provinciaController,
                            decoration: InputDecoration(
                              labelText: context.l10n.ordiniCampoProvincia,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _capController,
                      decoration: InputDecoration(
                        labelText: context.l10n.ordiniCampoCap,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.markunread_mailbox),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty ?? true
                          ? context.l10n.commonFieldRequired
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info box
            Card(
              color: theme.primaryColor.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.primaryColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        context.l10n.ordersAddProductsLaterHint,
                        style: TextStyle(color: theme.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isCreating ? null : () => Navigator.pop(context),
                  child: Text(context.l10n.commonAnnulla),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _creaOrdine,
                  child: _isCreating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.colors.onColoredSurface,
                            ),
                          ),
                        )
                      : Text(context.l10n.ordiniCreaOrdine),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
