import 'package:flutter/material.dart';
import '../class_coupon.dart';
import '../../theme/theme.dart';
import '../../l10n/extensions.dart';

/// Widget per visualizzare le statistiche dei coupon in modo compatto
class CouponStatsCompact extends StatelessWidget {
  final CouponStatsDisplay stats;
  final VoidCallback? onTap;

  const CouponStatsCompact({super.key, required this.stats, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: context.spacing.iL,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.primaryColor.withValues(alpha: 0.8),
              theme.primaryColor,
            ],
          ),
          borderRadius: context.shapes.m,
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text(
                  l10n.couponsStatistiche,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacing.l),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              mainAxisSpacing: context.spacing.m,
              crossAxisSpacing: context.spacing.m,
              children: [
                _buildStatItem(
                  context,
                  l10n.couponsStatTotali,
                  stats.totalCoupons.toString(),
                  Icons.confirmation_number,
                ),
                _buildStatItem(
                  context,
                  l10n.couponsStatAttivi,
                  stats.activeCoupons.toString(),
                  Icons.check_circle,
                ),
                _buildStatItem(
                  context,
                  l10n.couponsStatUtilizzi,
                  stats.totalUsage.toString(),
                  Icons.trending_up,
                ),
                _buildStatItem(
                  context,
                  l10n.couponsStatScontoTotale,
                  '€${stats.totalDiscount}',
                  Icons.euro,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: context.spacing.iS,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: context.shapes.s,
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget per visualizzare un piccolo badge del coupon
class CouponBadge extends StatelessWidget {
  final CouponDisplay coupon;
  final VoidCallback? onTap;

  const CouponBadge({super.key, required this.coupon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: context.shapes.s,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.m,
          vertical: context.spacing.s,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getTypeColor(context, coupon.discountType),
              _getTypeColor(
                context,
                coupon.discountType,
              ).withValues(alpha: 0.8),
            ],
          ),
          borderRadius: context.shapes.s,
          boxShadow: [
            BoxShadow(
              color: _getTypeColor(
                context,
                coupon.discountType,
              ).withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getTypeIcon(coupon.discountType),
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: context.spacing.s),
            Text(
              coupon.code,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(width: context.spacing.s),
            Text(
              coupon.discountDisplay,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
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
        return customColors.subtitleColor;
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
}

/// Widget per visualizzare la lista dei coupon in modo compatto
class CouponListCompact extends StatelessWidget {
  final List<CouponDisplay> coupons;
  final Function(CouponDisplay)? onCouponTap;
  final Function(CouponDisplay)? onCouponDelete;

  const CouponListCompact({
    super.key,
    required this.coupons,
    this.onCouponTap,
    this.onCouponDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (coupons.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      itemCount: coupons.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final coupon = coupons[index];
        return CouponListItemCompact(
          coupon: coupon,
          onTap: onCouponTap != null ? () => onCouponTap!(coupon) : null,
          onDelete: onCouponDelete != null
              ? () => onCouponDelete!(coupon)
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.discount_outlined,
            size: 64,
            color: theme.iconTheme.color?.withValues(alpha: 0.3),
          ),
          SizedBox(height: context.spacing.l),
          Text(
            context.l10n.couponsNessunCouponDisponibile,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget per visualizzare un singolo coupon in modo compatto
class CouponListItemCompact extends StatelessWidget {
  final CouponDisplay coupon;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const CouponListItemCompact({
    super.key,
    required this.coupon,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<AppColorExtension>()!;
    final isExpired = coupon.isExpired;
    final isActive = coupon.status == 'publish';
    final statoScaduto = Text(
      context.l10n.couponsStatusScaduto,
      style: theme.textTheme.labelSmall?.copyWith(
        color: customColors.errorColorStatus,
      ),
    );
    final statoAttivo = Text(
      context.l10n.couponsStatusAttivo,
      style: theme.textTheme.labelSmall?.copyWith(
        color: customColors.stockAvailable,
      ),
    );
    final statoNonAttivo = Text(
      context.l10n.couponsStatusNonAttivo,
      style: theme.textTheme.labelSmall?.copyWith(
        color: customColors.warningColor,
      ),
    );

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _getTypeColor(
            context,
            coupon.discountType,
          ).withValues(alpha: 0.2),
          borderRadius: context.shapes.s,
        ),
        child: Icon(
          _getTypeIcon(coupon.discountType),
          color: _getTypeColor(context, coupon.discountType),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              coupon.code,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.s,
              vertical: context.spacing.xs,
            ),
            decoration: BoxDecoration(
              color: customColors.stockAvailable.withValues(alpha: 0.2),
              borderRadius: context.shapes.m,
            ),
            child: Text(
              coupon.discountDisplay,
              style: theme.textTheme.labelSmall?.copyWith(
                color: customColors.stockAvailable,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: context.spacing.xs),
          if (coupon.description.isNotEmpty)
            Text(
              coupon.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          SizedBox(height: context.spacing.xs),
          Row(
            children: [
              Icon(
                isExpired
                    ? Icons.timer_off
                    : isActive
                    ? Icons.check_circle
                    : Icons.pause_circle,
                size: 12,
                color: isExpired
                    ? customColors.errorColorStatus
                    : isActive
                    ? customColors.stockAvailable
                    : customColors.warningColor,
              ),
              SizedBox(width: context.spacing.xs),
              isExpired
                  ? statoScaduto
                  : isActive
                  ? statoAttivo
                  : statoNonAttivo,
              SizedBox(width: context.spacing.m),
              Icon(
                Icons.calendar_today,
                size: 12,
                color: theme.iconTheme.color?.withValues(alpha: 0.6),
              ),
              SizedBox(width: context.spacing.xs),
              Text(
                coupon.expiryDisplay(context.l10n),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: onDelete != null
          ? IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: customColors.errorColorStatus,
              ),
              onPressed: onDelete,
            )
          : null,
      isThreeLine: coupon.description.isNotEmpty,
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
        return customColors.subtitleColor;
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
}

/// Widget per validare un coupon in tempo reale
class CouponValidationWidget extends StatefulWidget {
  final Function(String code)? onValidate;

  const CouponValidationWidget({super.key, this.onValidate});

  @override
  State<CouponValidationWidget> createState() => _CouponValidationWidgetState();
}

class _CouponValidationWidgetState extends State<CouponValidationWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _isValidating = false;
  String? _validationMessage;
  bool? _isValid;

  void _validate() {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isValidating = true;
      _validationMessage = null;
      _isValid = null;
    });

    widget.onValidate?.call(_controller.text);

    // Simulazione validazione (in realtà dovrebbe chiamare il servizio)
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isValidating = false;
          _isValid = true; // Esempio
          _validationMessage = context.l10n.couponsValido;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: context.spacing.iL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.couponsVerificaTitolo,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.spacing.m),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: l10n.couponsVerificaHint,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.confirmation_number),
                      suffixIcon: _isValidating
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : _isValid != null
                          ? Icon(
                              _isValid! ? Icons.check_circle : Icons.error,
                              color: _isValid!
                                  ? context.colors.successColor
                                  : context.colors.errorColorStatus,
                            )
                          : null,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _validate(),
                  ),
                ),
                SizedBox(width: context.spacing.s),
                ElevatedButton(
                  onPressed: _isValidating ? null : _validate,
                  child: Text(l10n.couponsVerificaAzione),
                ),
              ],
            ),
            if (_validationMessage != null) ...[
              SizedBox(height: context.spacing.m),
              Container(
                padding: context.spacing.iM,
                decoration: BoxDecoration(
                  color: (_isValid ?? false)
                      ? context.colors.successColor.withValues(alpha: 0.1)
                      : context.colors.errorColorStatus.withValues(alpha: 0.1),
                  borderRadius: context.shapes.s,
                  border: Border.all(
                    color: (_isValid ?? false)
                        ? context.colors.successColor
                        : context.colors.errorColorStatus,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (_isValid ?? false) ? Icons.check_circle : Icons.error,
                      color: (_isValid ?? false)
                          ? context.colors.successColor
                          : context.colors.errorColorStatus,
                    ),
                    SizedBox(width: context.spacing.s),
                    Expanded(
                      child: Text(
                        _validationMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: (_isValid ?? false)
                              ? context.colors.successColor
                              : context.colors.errorColorStatus,
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
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Widget per selezionare un coupon da una lista
class CouponSelectorDialog extends StatefulWidget {
  final List<CouponDisplay> coupons;
  final String? selectedCouponId;

  const CouponSelectorDialog({
    super.key,
    required this.coupons,
    this.selectedCouponId,
  });

  @override
  State<CouponSelectorDialog> createState() => _CouponSelectorDialogState();
}

class _CouponSelectorDialogState extends State<CouponSelectorDialog> {
  String? _selectedId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedCouponId;
  }

  List<CouponDisplay> get filteredCoupons {
    if (_searchQuery.isEmpty) return widget.coupons;
    return widget.coupons
        .where((c) => c.code.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: context.spacing.iL,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(context.shapes.radiusXS),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.discount, color: Colors.white),
                  SizedBox(width: context.spacing.s),
                  Text(
                    l10n.couponsSelezionaTitolo,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Ricerca
            Padding(
              padding: context.spacing.iL,
              child: TextField(
                decoration: InputDecoration(
                  hintText: l10n.couponsSelezionaHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            // Lista
            Expanded(
              child: RadioGroup<String>(
                groupValue: _selectedId,
                onChanged: (value) => setState(() => _selectedId = value),
                child: ListView.builder(
                  itemCount: filteredCoupons.length,
                  itemBuilder: (context, index) {
                    final coupon = filteredCoupons[index];
                    final isSelected = _selectedId == coupon.id.toString();

                    return ListTile(
                      selected: isSelected,
                      leading: Radio<String>(value: coupon.id.toString()),
                      title: Text(
                        coupon.code,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(coupon.discountDisplay),
                      trailing: coupon.isExpired
                          ? Chip(
                              label: Text(context.l10n.couponScaduto),
                              backgroundColor: context.colors.errorColorStatus,
                              labelStyle: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                              ),
                            )
                          : null,
                      onTap: () =>
                          setState(() => _selectedId = coupon.id.toString()),
                    );
                  },
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.commonAnnulla),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedId != null
                        ? () {
                            final selected = widget.coupons.firstWhere(
                              (c) => c.id.toString() == _selectedId,
                            );
                            Navigator.pop(context, selected);
                          }
                        : null,
                    child: Text(context.l10n.couponSeleziona),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
