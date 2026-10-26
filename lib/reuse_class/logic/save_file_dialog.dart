import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Chiede all'utente dove salvare [bytes] con la finestra di salvataggio di
/// sistema e li scrive li'.
///
/// Su Linux la finestra passa dal portale XDG, quindi funziona anche dentro
/// il Flatpak; su Android e' il selettore "crea documento" di sistema.
/// Nessuna cartella iniziale: Windows, macOS e i portali ricordano da soli
/// l'ultima cartella usata.
///
/// Restituisce il percorso (o il nome, dove non c'e' un percorso) del file
/// salvato, oppure null se l'utente annulla.
Future<String?> saveFileWithDialog({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
  String? dialogTitle,
}) async {
  final saved = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
  );
  if (saved == null) return null;
  if (saved.scheme == 'file') return saved.toFilePath();
  // Gli URI content:// di Android portano solo un id documento come
  // "primary:Download/report.pdf": si mostra l'ultima parte.
  final last = Uri.decodeComponent(
    saved.pathSegments.isEmpty ? '' : saved.pathSegments.last,
  );
  final name = last.split(RegExp(r'[/:]')).last;
  return name.isEmpty ? fileName : name;
}
