import '../../l10n/error_text.dart';
import 'package:flutter/material.dart';
import '../../notification/notification_service.dart';
import '../class_coupon.dart';
import '../../theme/theme.dart';
import 'coupon_list.code.dart';
import '../../l10n/extensions.dart';

/// Widget principale per la gestione dei coupon.
/// Supporta la gestione di coupon globali e per singolo utente.
class CouponGestisciView extends StatefulWidget {
  final String? userEmail; // Se presente, gestisce coupon per utente specifico

  const CouponGestisciView({super.key, this.userEmail});

  @override
  State<CouponGestisciView> createState() => _CouponGestisciViewState();
}

class _CouponGestisciViewState extends State<CouponGestisciView>
    with AutomaticKeepAliveClientMixin {
  final CouponGestisciController _controller = CouponGestisciController();

  // Filtri
  String? _filtroTipo;
  String? _filtroStatus;
  String _searchQuery = '';

  // UI State
  bool _isLoading = true;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _controller.loadCoupons(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: _filtroStatus,
        type: _filtroTipo,
        userEmail: widget.userEmail,
      );
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => CouponFormDialog(
        userEmail: widget.userEmail,
        onSaved: () {
          Navigator.of(context).pop();
          _loadCoupons();
        },
      ),
    );
  }

  void _showEditDialog(CouponGlobal coupon) {
    showDialog(
      context: context,
      builder: (context) => CouponFormDialog(
        coupon: coupon,
        userEmail: widget.userEmail,
        onSaved: () {
          Navigator.of(context).pop();
          _loadCoupons();
        },
      ),
    );
  }

  Future<void> _deleteCoupon(CouponGlobal coupon) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.couponConfermaEliminazione),
        content: Text(context.l10n.couponsDeleteConfirm(coupon.code)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonAnnulla),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.errorColorStatus,
            ),
            child: Text(context.l10n.couponEliminina),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _controller.deleteCoupon(coupon.id);
        if (!mounted) return;
        NotificationService.instance.messageBar(
          'successo',
          'coupon_gestisci',
          context.l10n.couponsDeleted,
        );
        _loadCoupons();
      } catch (e) {
        if (!mounted) return;
        NotificationService.instance.messageBar(
          'errore',
          'coupon_gestisci',
          context.l10n.couponsErrorDetail(localizedErrorText(context.l10n, e)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necessario per AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.userEmail != null
              ? context.l10n.couponsForCustomer('${widget.userEmail}')
              : context.l10n.couponsManageTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCoupons,
            tooltip: context.l10n.couponRicarica,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
            tooltip: context.l10n.couponNuovoCoupon,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(theme),
          _buildStatisticsCard(theme, customColors),
          Expanded(child: _buildContent(theme, customColors)),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barra di ricerca
          TextField(
            decoration: InputDecoration(
              hintText: context.l10n.couponSearchByCodeHint,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.brightness == Brightness.dark
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.surfaceContainerLow,
            ),
            onChanged: (value) {
              _searchQuery = value;
              _loadCoupons();
            },
          ),
          const SizedBox(height: 12),
          // Filtri
          Row(
            children: [
              Expanded(
                child: _buildDropdownFilter(
                  theme,
                  context.l10n.couponsFilterType,
                  _filtroTipo,
                  [
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.l10n.couponTutti),
                    ),
                    DropdownMenuItem(
                      value: 'percent',
                      child: Text(context.l10n.couponTipoconSconto),
                    ),
                    DropdownMenuItem(
                      value: 'fixed_cart',
                      child: Text(context.l10n.couponFissoCarrello),
                    ),
                    DropdownMenuItem(
                      value: 'fixed_product',
                      child: Text(context.l10n.couponFissoProdotto),
                    ),
                  ],
                  (value) {
                    setState(() {
                      _filtroTipo = value;
                      _loadCoupons();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownFilter(
                  theme,
                  context.l10n.couponsFilterStatus,
                  _filtroStatus,
                  [
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.l10n.couponTutti),
                    ),
                    DropdownMenuItem(
                      value: 'publish',
                      child: Text(context.l10n.couponPubblicato),
                    ),
                    DropdownMenuItem(
                      value: 'draft',
                      child: Text(context.l10n.couponBozza),
                    ),
                    DropdownMenuItem(
                      value: 'trash',
                      child: Text(context.l10n.couponCestino),
                    ),
                  ],
                  (value) {
                    setState(() {
                      _filtroStatus = value;
                      _loadCoupons();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter<T>(
    ThemeData theme,
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
  ) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surfaceContainerLow,
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildStatisticsCard(ThemeData theme, AppColorExtension customColors) {
    if (_controller.stats == null) return const SizedBox.shrink();

    final stats = _controller.stats!;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.headerGradientStart,
            context.colors.headerGradientEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            theme,
            context.l10n.couponsStatTotali,
            stats.totalCoupons.toString(),
            Icons.confirmation_number,
          ),
          _buildStatItem(
            theme,
            context.l10n.couponsStatAttivi,
            stats.activeCoupons.toString(),
            Icons.check_circle,
          ),
          _buildStatItem(
            theme,
            context.l10n.couponsStatUtilizzi,
            stats.totalUsage.toString(),
            Icons.trending_up,
          ),
          _buildStatItem(
            theme,
            context.l10n.couponsStatDiscountShort,
            '€${stats.totalDiscount}',
            Icons.euro,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: context.colors.onColoredSurface, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: context.colors.onColoredSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.colors.onColoredSurface.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme, AppColorExtension customColors) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.primaryColor),
      );
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
            Text(
              context.l10n.couponErroreCaricamento,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCoupons,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.couponRiprova),
            ),
          ],
        ),
      );
    }

    if (_controller.coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.discount_outlined,
              size: 80,
              color: theme.iconTheme.color?.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.couponNessunCouponTrovato,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.couponsCreateFirst,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.couponNuovoCoupon),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _controller.coupons.length,
      itemBuilder: (context, index) {
        final coupon = _controller.coupons[index];
        return CouponCard(
          coupon: coupon,
          onEdit: () => _showEditDialog(coupon),
          onDelete: () => _deleteCoupon(coupon),
          onToggleStatus: () async {
            try {
              await _controller.toggleCouponStatus(coupon);
              _loadCoupons();
            } catch (e) {
              if (!mounted) return;
              NotificationService.instance.messageBar(
                'errore',
                'coupon_gestisci',
                context.l10n.couponsErrorDetail(
                  localizedErrorText(context.l10n, e),
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Card per visualizzare un singolo coupon
class CouponCard extends StatelessWidget {
  final CouponGlobal coupon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const CouponCard({
    super.key,
    required this.coupon,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final isExpired = coupon.isExpired;
    final isActive = coupon.status == 'publish';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpired
              ? customColors.errorColorStatus.withValues(alpha: 0.3)
              : isActive
              ? theme.primaryColor.withValues(alpha: 0.3)
              : theme.dividerColor,
          width: isExpired || isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Badge tipo coupon
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getTypeColor(context, coupon.discountType),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTypeIcon(coupon.discountType),
                        size: 16,
                        color: context.colors.onColoredSurface,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getTypeLabel(context, coupon.discountType),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: context.colors.onColoredSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Badge status
                _buildStatusBadge(context, theme, customColors),
                const Spacer(),
                // Azioni rapide
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'toggle':
                        onToggleStatus();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text(context.l10n.couponModifica),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(isActive ? Icons.pause : Icons.play_arrow),
                          const SizedBox(width: 8),
                          Text(
                            isActive
                                ? context.l10n.couponsDeactivate
                                : context.l10n.couponsActivate,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            color: customColors.errorColorStatus,
                          ),
                          SizedBox(width: 8),
                          Text(
                            context.l10n.couponEliminina,
                            style: TextStyle(
                              color: customColors.errorColorStatus,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Codice coupon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.confirmation_number, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    coupon.code,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    coupon.discountDisplay,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: customColors.stockAvailable,
                    ),
                  ),
                ],
              ),
            ),
            if (coupon.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                coupon.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Informazioni aggiuntive
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  theme,
                  Icons.calendar_today,
                  context.l10n.couponsExpiryValue(
                    coupon.expiryDisplay(context.l10n),
                  ),
                  isExpired ? customColors.errorColorStatus : null,
                ),
                if (coupon.usageLimit != null)
                  _buildInfoChip(
                    theme,
                    Icons.repeat,
                    context.l10n.couponsUsageValue(
                      '${coupon.usageCount}',
                      '${coupon.usageLimit}',
                    ),
                  ),
                if (coupon.minimumAmount != null)
                  _buildInfoChip(
                    theme,
                    Icons.shopping_cart,
                    context.l10n.couponsMinimumValue(
                      '€${coupon.minimumAmount}',
                    ),
                  ),
                if (coupon.freeShipping)
                  _buildInfoChip(
                    theme,
                    Icons.local_shipping,
                    context.l10n.couponSpedizioneGratuita,
                    customColors.successColor,
                  ),
                if (coupon.emailRestrictions.isNotEmpty)
                  _buildInfoChip(
                    theme,
                    Icons.person,
                    context.l10n.couponsEmailValue(
                      coupon.emailRestrictions.first,
                    ),
                    customColors.infoColor,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    ThemeData theme,
    AppColorExtension customColors,
  ) {
    Color color;
    String label;
    IconData icon;

    if (coupon.isExpired) {
      color = customColors.errorColorStatus;
      label = context.l10n.couponsBadgeExpired;
      icon = Icons.timer_off;
    } else if (coupon.status == 'publish') {
      color = customColors.stockAvailable;
      label = context.l10n.couponsBadgeActive;
      icon = Icons.check_circle;
    } else if (coupon.status == 'draft') {
      color = customColors.warningColor;
      label = context.l10n.couponsBadgeDraft;
      icon = Icons.edit;
    } else {
      color = customColors.neutralColor;
      label = context.l10n.couponsBadgeTrash;
      icon = Icons.delete;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    ThemeData theme,
    IconData icon,
    String label, [
    Color? color,
  ]) {
    final chipColor =
        color ??
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
        theme.colorScheme.onSurfaceVariant;

    return Chip(
      avatar: Icon(icon, size: 16, color: chipColor),
      label: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(color: chipColor),
      ),
      backgroundColor: chipColor.withValues(alpha: 0.1),
      side: BorderSide(color: chipColor.withValues(alpha: 0.3)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Color _getTypeColor(BuildContext context, String type) {
    final customColors = Theme.of(context).extension<AppColorExtension>()!;
    switch (type) {
      case 'percent':
        return customColors.infoColor;
      case 'fixed_cart':
        return customColors.infoColor;
      case 'fixed_product':
        return customColors.successColor;
      default:
        return customColors.neutralColor;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'percent':
        return Icons.percent;
      case 'fixed_cart':
        return Icons.shopping_cart;
      case 'fixed_product':
        return Icons.inventory;
      default:
        return Icons.discount;
    }
  }

  String _getTypeLabel(BuildContext context, String type) {
    switch (type) {
      case 'percent':
        return context.l10n.couponTipoconSconto;
      case 'fixed_cart':
        return context.l10n.couponFissoCarrello;
      case 'fixed_product':
        return context.l10n.couponFissoProdotto;
      default:
        return context.l10n.couponOtherType;
    }
  }
}

/// Dialog per creare/modificare un coupon
class CouponFormDialog extends StatefulWidget {
  final CouponGlobal? coupon;
  final String? userEmail;
  final VoidCallback onSaved;

  const CouponFormDialog({
    super.key,
    this.coupon,
    this.userEmail,
    required this.onSaved,
  });

  @override
  State<CouponFormDialog> createState() => _CouponFormDialogState();
}

class _CouponFormDialogState extends State<CouponFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final CouponGestisciController _controller = CouponGestisciController();

  late TextEditingController _codeController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _minimumAmountController;
  late TextEditingController _maximumAmountController;
  late TextEditingController _usageLimitController;
  late TextEditingController _usageLimitPerUserController;

  String _discountType = 'percent';
  String _status = 'publish';
  bool _freeShipping = false;
  bool _excludeSaleItems = false;
  DateTime? _dateExpires;
  List<String> _emailRestrictions = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Inizializza i controller
    _codeController = TextEditingController(text: widget.coupon?.code ?? '');
    _amountController = TextEditingController(
      text: widget.coupon?.amount ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.coupon?.description ?? '',
    );
    _minimumAmountController = TextEditingController(
      text: widget.coupon?.minimumAmount ?? '',
    );
    _maximumAmountController = TextEditingController(
      text: widget.coupon?.maximumAmount ?? '',
    );
    _usageLimitController = TextEditingController(
      text: widget.coupon?.usageLimit?.toString() ?? '',
    );
    _usageLimitPerUserController = TextEditingController(
      text: widget.coupon?.usageLimitPerUser?.toString() ?? '',
    );

    if (widget.coupon != null) {
      _discountType = widget.coupon!.discountType;
      _status = widget.coupon!.status;
      _freeShipping = widget.coupon!.freeShipping;
      _excludeSaleItems = widget.coupon!.excludeSaleItems;
      _dateExpires = widget.coupon!.dateExpires;
      _emailRestrictions = List.from(widget.coupon!.emailRestrictions);
    }

    // Se c'è un userEmail, aggiungilo alle restrizioni
    if (widget.userEmail != null &&
        !_emailRestrictions.contains(widget.userEmail)) {
      _emailRestrictions.add(widget.userEmail!);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (widget.coupon == null) {
        // Crea nuovo coupon
        await _controller.createCoupon(
          code: _codeController.text,
          discountType: _discountType,
          amount: _amountController.text,
          status: _status,
          description: _descriptionController.text,
          dateExpires: _dateExpires,
          usageLimit: int.tryParse(_usageLimitController.text),
          usageLimitPerUser: int.tryParse(_usageLimitPerUserController.text),
          freeShipping: _freeShipping,
          excludeSaleItems: _excludeSaleItems,
          minimumAmount: _minimumAmountController.text.isEmpty
              ? null
              : _minimumAmountController.text,
          maximumAmount: _maximumAmountController.text.isEmpty
              ? null
              : _maximumAmountController.text,
          emailRestrictions: _emailRestrictions.isEmpty
              ? null
              : _emailRestrictions,
        );
      } else {
        // Aggiorna coupon esistente
        await _controller.updateCoupon(
          widget.coupon!.id,
          code: _codeController.text,
          discountType: _discountType,
          amount: _amountController.text,
          status: _status,
          description: _descriptionController.text,
          dateExpires: _dateExpires,
          usageLimit: int.tryParse(_usageLimitController.text),
          usageLimitPerUser: int.tryParse(_usageLimitPerUserController.text),
          freeShipping: _freeShipping,
          excludeSaleItems: _excludeSaleItems,
          minimumAmount: _minimumAmountController.text.isEmpty
              ? null
              : _minimumAmountController.text,
          maximumAmount: _maximumAmountController.text.isEmpty
              ? null
              : _maximumAmountController.text,
          emailRestrictions: _emailRestrictions.isEmpty
              ? null
              : _emailRestrictions,
        );
      }

      if (!mounted) return;
      NotificationService.instance.messageBar(
        'successo',
        'coupon_gestisci',
        widget.coupon == null
            ? context.l10n.couponsCreated
            : context.l10n.couponsUpdated,
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      NotificationService.instance.messageBar(
        'errore',
        'coupon_gestisci',
        context.l10n.couponsErrorDetail(localizedErrorText(context.l10n, e)),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.coupon == null ? Icons.add : Icons.edit,
                    color: context.colors.onColoredSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.coupon == null
                        ? context.l10n.couponNuovoCoupon
                        : context.l10n.couponsEditTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: context.colors.onColoredSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: context.colors.onColoredSurface,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          labelText: context.l10n.couponCodeRequired,
                          hintText: context.l10n.couponsCodeExample,
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) => value?.isEmpty ?? true
                            ? context.l10n.commonFieldRequired
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _discountType,
                        decoration: InputDecoration(
                          labelText: context.l10n.couponDiscountType,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'percent',
                            child: Text(context.l10n.couponTipoconSconto),
                          ),
                          DropdownMenuItem(
                            value: 'fixed_cart',
                            child: Text(context.l10n.couponFissoCarrello),
                          ),
                          DropdownMenuItem(
                            value: 'fixed_product',
                            child: Text(context.l10n.couponFissoProdotto),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _discountType = value!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: _discountType == 'percent'
                              ? context.l10n.couponsPercentRequired
                              : context.l10n.couponsAmountRequired,
                          hintText: _discountType == 'percent'
                              ? 'es. 20'
                              : 'es. 10.00',
                          border: const OutlineInputBorder(),
                          suffixText: _discountType == 'percent' ? '%' : '€',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty ?? true
                            ? context.l10n.commonFieldRequired
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: context.l10n.commonDescription,
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: InputDecoration(
                          labelText: context.l10n.couponStatus,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'publish',
                            child: Text(context.l10n.couponPubblicato),
                          ),
                          DropdownMenuItem(
                            value: 'draft',
                            child: Text(context.l10n.couponBozza),
                          ),
                        ],
                        onChanged: (value) => setState(() => _status = value!),
                      ),
                      const SizedBox(height: 16),
                      // Data scadenza
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _dateExpires ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 5),
                            ),
                          );
                          if (date != null) {
                            setState(() => _dateExpires = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: context.l10n.couponExpiryDate,
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _dateExpires != null
                                ? '${_dateExpires!.day}/${_dateExpires!.month}/${_dateExpires!.year}'
                                : context.l10n.couponsNessunaScadenza,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _usageLimitController,
                              decoration: InputDecoration(
                                labelText: context.l10n.couponUsageLimit,
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _usageLimitPerUserController,
                              decoration: InputDecoration(
                                labelText: context.l10n.couponLimitPerUser,
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _minimumAmountController,
                              decoration: InputDecoration(
                                labelText: context.l10n.couponMinimumAmount,
                                border: OutlineInputBorder(),
                                prefixText: '€ ',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _maximumAmountController,
                              decoration: InputDecoration(
                                labelText: context.l10n.couponMaximumAmount,
                                border: OutlineInputBorder(),
                                prefixText: '€ ',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(context.l10n.couponSpedizioneGratuita),
                        value: _freeShipping,
                        onChanged: (value) =>
                            setState(() => _freeShipping = value),
                      ),
                      SwitchListTile(
                        title: Text(context.l10n.couponEscludiProdottiInSaldo),
                        value: _excludeSaleItems,
                        onChanged: (value) =>
                            setState(() => _excludeSaleItems = value),
                      ),
                      if (widget.userEmail != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.primaryColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person, color: theme.primaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.l10n.couponsReservedFor(
                                    '${widget.userEmail}',
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text(context.l10n.commonAnnulla),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.coupon == null
                                ? context.l10n.couponsCreate
                                : context.l10n.commonSave,
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

  @override
  void dispose() {
    _codeController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _minimumAmountController.dispose();
    _maximumAmountController.dispose();
    _usageLimitController.dispose();
    _usageLimitPerUserController.dispose();
    _controller.dispose();
    super.dispose();
  }
}
