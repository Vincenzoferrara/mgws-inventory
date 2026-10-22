// Dialog per aggiungere/modificare commenti alle inserzioni
//
// UI semplice per gestire i commenti sulle ads

import 'package:flutter/material.dart';
import '../notification/notification_service.dart';
import 'ads_comment_manager.dart';
import '../l10n/extensions.dart';

/// Dialog per aggiungere o modificare un commento su un'inserzione
class AdsCommentDialog extends StatefulWidget {
  final String adId;
  final String platform;
  final String accountId;
  final String adTitle; // Titolo dell'inserzione per mostrare all'utente
  final AdsComment? existingComment;

  const AdsCommentDialog({
    Key? key,
    required this.adId,
    required this.platform,
    required this.accountId,
    required this.adTitle,
    this.existingComment,
  }) : super(key: key);

  @override
  State<AdsCommentDialog> createState() => _AdsCommentDialogState();
}

class _AdsCommentDialogState extends State<AdsCommentDialog> {
  late TextEditingController _commentController;
  final _commentManager = AdsCommentManager();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(
      text: widget.existingComment?.comment ?? '',
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _saveComment() async {
    if (_commentController.text.trim().isEmpty) {
      NotificationService.instance.messageBar(
        'warning',
        'ads_comment_dialog',
        'Il commento non può essere vuoto',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _commentManager.setComment(
        widget.adId,
        widget.platform,
        widget.accountId,
        _commentController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Ritorna true per indicare successo
        NotificationService.instance.messageBar(
          'successo',
          'ads_comment_dialog',
          'Commento salvato con successo',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.messageBar(
          'errore',
          'ads_comment_dialog',
          'Errore nel salvare il commento: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteComment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.prodottiConfermaEliminazione),
        content: Text(context.l10n.dashboardConfermaEliminazioneCommento),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonAnnulla),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      await _commentManager.removeComment(
        widget.adId,
        widget.platform,
        widget.accountId,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        NotificationService.instance.messageBar(
          'successo',
          'ads_comment_dialog',
          'Commento eliminato',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.messageBar(
          'errore',
          'ads_comment_dialog',
          'Errore nell\'eliminare il commento: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.existingComment != null
                ? 'Modifica commento'
                : 'Aggiungi commento',
          ),
          const SizedBox(height: 8),
          Text(
            widget.adTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: context.l10n.dashboardCommento,
                hintText: context.l10n.dashboardInserisciCommento,
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              maxLength: 1000,
              enabled: !_isSaving,
            ),
            const SizedBox(height: 8),
            if (widget.existingComment != null) ...[
              Text(
                'Creato: ${_formatDate(widget.existingComment!.timestamp)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              if (widget.existingComment!.timestamp !=
                  widget.existingComment!.lastModified)
                Text(
                  'Ultima modifica: ${_formatDate(widget.existingComment!.lastModified)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.existingComment != null)
          TextButton.icon(
            onPressed: _isSaving ? null : _deleteComment,
            icon: const Icon(Icons.delete, color: Colors.red),
            label: Text(
              context.l10n.commonDelete,
              style: TextStyle(color: Colors.red),
            ),
          ),
        const Spacer(),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonAnnulla),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveComment,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.commonSave),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Mostra il dialog per aggiungere/modificare un commento
Future<bool?> showAdsCommentDialog({
  required BuildContext context,
  required String adId,
  required String platform,
  required String accountId,
  required String adTitle,
  AdsComment? existingComment,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AdsCommentDialog(
      adId: adId,
      platform: platform,
      accountId: accountId,
      adTitle: adTitle,
      existingComment: existingComment,
    ),
  );
}
