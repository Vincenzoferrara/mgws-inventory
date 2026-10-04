import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:mgws_inventory/log_viewer/app_logger.dart';
import '../../../notification/notification_service.dart';
import '../../../settings/prodotti_image_settings.dart';
import '../../../login/jwt_api/query_woocommerce/woo_query_media.dart';
import '../../../login/jwt_api/class_prodotti.dart';
import '../../../reuse_class/image_url_resolver.dart';
import '../../../traduzioni/estensioni.dart';

/// Dialog per selezionare immagini dalla libreria media di WordPress
class MediaSelectorDialog extends StatefulWidget {
  final bool showDimensionWarnings;
  final int warningThresholdWidth;
  final int warningThresholdHeight;
  final bool multiSelect;

  const MediaSelectorDialog({
    super.key,
    this.showDimensionWarnings = true,
    this.warningThresholdWidth = 720,
    this.warningThresholdHeight = 1080,
    this.multiSelect = false,
  });

  @override
  State<MediaSelectorDialog> createState() => _MediaSelectorDialogState();
}

class _MediaSelectorDialogState extends State<MediaSelectorDialog> {
  final WooQueryMedia _mediaQuery = WooQueryMedia();

  List<MediaFile> _images = [];
  final Set<String> _selectedUrls = <String>{};
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  final int _perPage = 20;
  bool _hasMorePages = true;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Stato per drag & drop e upload
  bool _isDragging = false;
  bool _isUploading = false;
  String? _uploadingFileName;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading && _hasMorePages) {
        _loadMoreImages();
      }
    }
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
      _images.clear();
    });

    try {
      final images = await _mediaQuery.getImages(
        page: _currentPage,
        perPage: _perPage,
      );

      if (mounted) {
        setState(() {
          _images = images;
          _hasMorePages = images.length == _perPage;
          _isLoading = false;
        });
      }
    } catch (e) {
      log.e('Errore caricamento immagini', e);
      if (mounted) {
        setState(() {
          _error = 'Errore nel caricamento: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreImages() async {
    if (_isLoading || !_hasMorePages) return;

    setState(() {
      _isLoading = true;
      _currentPage++;
    });

    try {
      final newImages = await _mediaQuery.getImages(
        page: _currentPage,
        perPage: _perPage,
      );

      if (mounted) {
        setState(() {
          _images.addAll(newImages);
          _hasMorePages = newImages.length == _perPage;
          _isLoading = false;
        });
      }
    } catch (e) {
      log.e('Errore caricamento pagina $_currentPage', e);
      if (mounted) {
        setState(() {
          _currentPage--;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchImages(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
      _images.clear();
    });

    try {
      final images = await _mediaQuery.getMediaList(
        page: 1,
        perPage: _perPage,
        search: query.isEmpty ? null : query,
        mimeType: 'image',
      );

      if (mounted) {
        setState(() {
          _images = images;
          _hasMorePages = images.length == _perPage;
          _isLoading = false;
        });
      }
    } catch (e) {
      log.e('Errore ricerca immagini', e);
      if (mounted) {
        setState(() {
          _error = 'Errore nella ricerca: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Seleziona e carica un'immagine dal file system
  Future<void> _pickAndUploadImage() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (file == null) {
        return; // Utente ha annullato
      }

      if (file.path == null) {
        throw Exception('Percorso file non valido');
      }

      await _uploadFile(file.path!, file.name);
    } catch (e) {
      log.e('Errore selezione file', e);
      if (mounted) {
        NotificationService.instance.messageBar(
          'errore',
          'media_selector_dialog',
          'Errore nella selezione del file: $e',
        );
      }
    }
  }

  /// Gestisce file trascinati (drag & drop)
  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    if (details.files.isEmpty) return;

    // Prendi solo il primo file se sono stati trascinati più file
    final file = details.files.first;

    // Verifica che sia un'immagine
    final extension = file.path.split('.').last.toLowerCase();
    final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'];

    if (!validExtensions.contains(extension)) {
      if (mounted) {
        NotificationService.instance.messageBar(
          'warning',
          'media_selector_dialog',
          'Per favore trascina solo file immagine (jpg, png, gif, webp, svg)',
        );
      }
      return;
    }

    await _uploadFile(file.path, file.name);
  }

  /// Carica un file su WordPress
  Future<void> _uploadFile(String filePath, String fileName) async {
    setState(() {
      _isUploading = true;
      _uploadingFileName = fileName;
    });

    try {
      log.d('📤 Inizio upload: $fileName');

      final uploadedMedia = await _mediaQuery.uploadMedia(
        filePath,
        title: fileName.split('.').first,
      );

      log.d(
        '✅ Upload completato: ${uploadedMedia.id} - ${uploadedMedia.title}',
      );

      if (mounted) {
        NotificationService.instance.messageBar(
          'successo',
          'media_selector_dialog',
          'Immagine "$fileName" caricata con successo!',
        );

        // Ricarica la lista immagini per mostrare quella appena caricata
        await _loadImages();
      }
    } catch (e) {
      log.e('❌ Errore upload file', e);
      if (mounted) {
        NotificationService.instance.messageBar(
          'errore',
          'media_selector_dialog',
          'Errore nel caricamento: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingFileName = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: DropTarget(
          onDragEntered: (details) {
            setState(() => _isDragging = true);
          },
          onDragExited: (details) {
            setState(() => _isDragging = false);
          },
          onDragDone: (details) {
            setState(() => _isDragging = false);
            _handleDroppedFiles(details);
          },
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.photo_library, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        widget.multiSelect
                            ? 'Seleziona Immagini'
                            : 'Seleziona Immagine',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (widget.multiSelect) ...[
                        Text(
                          '${_selectedUrls.length} selezionate',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _selectedUrls.isEmpty
                              ? null
                              : () {
                                  final selected = _images
                                      .where(
                                        (image) =>
                                            _selectedUrls.contains(image.url),
                                      )
                                      .toList(growable: false);
                                  Navigator.of(context).pop(selected);
                                },
                          icon: const Icon(Icons.check),
                          label: Text(context.l10n.prodottiConfermaSelezione),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Pulsante Carica
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _pickAndUploadImage,
                        icon: const Icon(Icons.upload_file),
                        label: Text(context.l10n.prodottiCarica),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Barra di ricerca
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.l10n.prodottiCercaImmagini,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _searchImages('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: _searchImages,
                  ),
                  const SizedBox(height: 16),

                  // Indicatore upload
                  if (_isUploading)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Caricamento in corso...',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (_uploadingFileName != null)
                                  Text(
                                    _uploadingFileName!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Contatore immagini
                  if (_images.isNotEmpty && !_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        widget.multiSelect
                            ? '${_images.length} immagini trovate • ${_selectedUrls.length} selezionate'
                            : '${_images.length} immagini trovate',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),

                  // Griglia immagini
                  Expanded(child: _buildContent()),
                ],
              ),

              // Overlay drag & drop
              if (_isDragging)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Colors.blue,
                      width: 3,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_upload,
                            size: 64,
                            color: Colors.blue,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Rilascia qui per caricare',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadImages,
              child: Text(context.l10n.inventoryRiprova),
            ),
          ],
        ),
      );
    }

    if (_isLoading && _images.isEmpty) {
      return  Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(context.l10n.prodottiCaricamentoImmagini),
          ],
        ),
      );
    }

    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nessuna immagine trovata',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              final image = _images[index];
              return _buildImageCard(image);
            },
          ),
        ),
        if (_isLoading && _images.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildImageCard(MediaFile image) {
    final isSelected = _selectedUrls.contains(image.url);
    final isOversized = isProductImageOverWarningThreshold(
      width: image.width,
      height: image.height,
      warningsEnabled: widget.showDimensionWarnings,
      thresholdWidth: widget.warningThresholdWidth,
      thresholdHeight: widget.warningThresholdHeight,
    );

    return InkWell(
      onTap: () {
        if (!widget.multiSelect) {
          Navigator.of(context).pop(image);
          return;
        }
        final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
        final isCtrlPressed =
            pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
            pressedKeys.contains(LogicalKeyboardKey.controlRight) ||
            pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
            pressedKeys.contains(LogicalKeyboardKey.metaRight);
        setState(() {
          if (isCtrlPressed) {
            if (isSelected) {
              _selectedUrls.remove(image.url);
            } else {
              _selectedUrls.add(image.url);
            }
          } else {
            _selectedUrls
              ..clear()
              ..add(image.url);
          }
        });
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: isSelected ? 6 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Immagine
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    resolveImageUrl(image.url) ?? '',
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 48),
                      );
                    },
                  ),
                  // Overlay hover
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                  if (widget.multiSelect)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value ?? false) {
                                _selectedUrls.add(image.url);
                              } else {
                                _selectedUrls.remove(image.url);
                              }
                            });
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    image.title ?? 'Immagine senza titolo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (image.width != null && image.height != null)
                    Text(
                      '${image.width} × ${image.height}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  if (isOversized) ...[
                    const SizedBox(height: 4),
                    ProductImageDimensionWarningBadge(
                      width: image.width!,
                      height: image.height!,
                      thresholdWidth: widget.warningThresholdWidth,
                      thresholdHeight: widget.warningThresholdHeight,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductImageDimensionWarningBadge extends StatelessWidget {
  final int width;
  final int height;
  final int thresholdWidth;
  final int thresholdHeight;

  const ProductImageDimensionWarningBadge({
    super.key,
    required this.width,
    required this.height,
    required this.thresholdWidth,
    required this.thresholdHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'Dimensioni $width × $height sopra soglia $thresholdWidth × $thresholdHeight px',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 12,
                color: Colors.orange,
              ),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Oltre soglia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Metodo helper per mostrare il dialog e ottenere l'immagine selezionata
Future<MediaFile?> showMediaSelector(
  BuildContext context, {
  bool showDimensionWarnings = true,
  int warningThresholdWidth = 720,
  int warningThresholdHeight = 1080,
}) async {
  return await showDialog<MediaFile>(
    context: context,
    builder: (context) => MediaSelectorDialog(
      showDimensionWarnings: showDimensionWarnings,
      warningThresholdWidth: warningThresholdWidth,
      warningThresholdHeight: warningThresholdHeight,
    ),
  );
}

/// Metodo helper per mostrare il dialog e ottenere una o più immagini selezionate.
Future<List<MediaFile>?> showMediaSelectorMulti(
  BuildContext context, {
  bool showDimensionWarnings = true,
  int warningThresholdWidth = 720,
  int warningThresholdHeight = 1080,
}) async {
  return await showDialog<List<MediaFile>>(
    context: context,
    builder: (context) => MediaSelectorDialog(
      showDimensionWarnings: showDimensionWarnings,
      warningThresholdWidth: warningThresholdWidth,
      warningThresholdHeight: warningThresholdHeight,
      multiSelect: true,
    ),
  );
}
