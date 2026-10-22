// Modello dati per i file media (immagini prodotto).
// Indipendente dal backend: le query della piattaforma lo costruiscono.

/// Media/File upload
class MediaFile {
  final int id;
  final String url;
  final String? title;
  final String? altText;
  final String? caption;
  final String mimeType;
  final int? width;
  final int? height;
  final int? fileSize;
  final DateTime? dataCreazione;

  MediaFile({
    required this.id,
    required this.url,
    this.title,
    this.altText,
    this.caption,
    required this.mimeType,
    this.width,
    this.height,
    this.fileSize,
    this.dataCreazione,
  });

  /// Verifica se è un'immagine
  bool get isImmagine => mimeType.startsWith('image/');

  /// Dimensione formattata
  String get dimensioneFormattata {
    if (fileSize == null) return 'N/A';
    final size = fileSize!;
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  // Backward compatibility getters
  String get nome => title ?? '';
  int get dimensione => fileSize ?? 0;
  DateTime get dataUpload => dataCreazione ?? DateTime.now();
  String? get didascalia => caption;
}
