import 'package:material_ui/material_ui.dart';

import '../../../l10n/extensions.dart';
import '../uhf_tag_assignment.code.dart';

/// Editor section for the EPCs assigned to one product or variation.
class RfidTagAssignmentSection extends StatefulWidget {
  const RfidTagAssignmentSection({
    super.key,
    required this.epcs,
    required this.onAdd,
    required this.onRemove,
  });

  /// Raw EPCs currently assigned to the selected target.
  final List<String> epcs;

  /// Returns false when the value is invalid or already in the list.
  final bool Function(String raw) onAdd;
  final void Function(String raw) onRemove;

  @override
  State<RfidTagAssignmentSection> createState() =>
      _RfidTagAssignmentSectionState();
}

class _RfidTagAssignmentSectionState extends State<RfidTagAssignmentSection> {
  final _epcController = TextEditingController();
  String? _validationMessage;

  @override
  void dispose() {
    _epcController.dispose();
    super.dispose();
  }

  void _addEpc() {
    final raw = _epcController.text;
    if (RfidTagAssignmentController.normalizeEpc(raw) == null) {
      setState(() => _validationMessage = context.l10n.productsRfidInvalid);
      return;
    }
    if (!widget.onAdd(raw)) {
      setState(() => _validationMessage = context.l10n.productsRfidDuplicate);
      return;
    }
    _epcController.clear();
    setState(() => _validationMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.productsRfidTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.productsRfidHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _epcController,
                    decoration: InputDecoration(
                      labelText: context.l10n.productsRfidEpcLabel,
                      errorText: _validationMessage,
                      isDense: true,
                      prefixIcon: const Icon(Icons.nfc_outlined),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) {
                      if (_validationMessage != null) {
                        setState(() => _validationMessage = null);
                      }
                    },
                    onSubmitted: (_) => _addEpc(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addEpc,
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.productsRfidAdd),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.epcs.isEmpty)
              Text(
                context.l10n.productsRfidEmpty,
                style: theme.textTheme.bodySmall,
              )
            else
              Column(
                children: [
                  for (final epc in widget.epcs)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.label_outline),
                      title: Text(epc),
                      trailing: IconButton(
                        onPressed: () => widget.onRemove(epc),
                        icon: const Icon(Icons.close),
                        tooltip: context.l10n.productsRfidRemove,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
