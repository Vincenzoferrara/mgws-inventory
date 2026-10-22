import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../log_viewer/app_logger.dart';
import '../../theme/theme.dart';
import 'datagridview.code.dart';

class DataGridView<T> extends StatefulWidget {
  final List<DataGridViewColumn> columns;
  final List<DataGridViewRowData<T>> rows;
  final String? selectedRowId;
  final Set<String> selectedRowIds;
  final ValueChanged<T>? onRowSelected;
  final ValueChanged<T>? onRowDoubleTap;

  /// Tocco singolo completato (non scatta su pressione prolungata né su
  /// scroll). Serve dove non c'è un pannello laterale, cioè su telefono.
  final ValueChanged<T>? onRowTap;
  final Future<void> Function(TapDownDetails details, T value)?
  onRowSecondaryTap;
  final List<DataGridViewContextAction<T>> contextActions;
  final void Function(T value, bool selected)? onRowChecked;
  final ValueChanged<bool>? onSelectAll;
  final ValueChanged<T?>? onDeleteShortcut;
  final VoidCallback? onEscapeShortcut;
  final String selectAllShortcut;
  final String deleteShortcut;
  final String escapeShortcut;
  final ScrollController? verticalScrollController;
  final bool showCheckboxes;
  final bool autofocus;

  /// Disegna intorno alla tabella la cornice (bordo, raggio, ombra).
  ///
  /// Va lasciato `true` quando la griglia e l'unico elemento decorato del
  /// proprio riquadro, come nei caller di inventory. Va messo `false` quando
  /// il contenitore che la ospita ha gia un bordo: in quel caso due cornici a
  /// pochi pixel di distanza si leggono come un bordo dentro un bordo, e il
  /// padding della cornice toglie spazio utile alle colonne.
  final bool framed;

  const DataGridView({
    super.key,
    this.columns = const <DataGridViewColumn>[],
    this.rows = const [],
    this.selectedRowId,
    this.selectedRowIds = const <String>{},
    this.onRowSelected,
    this.onRowDoubleTap,
    this.onRowTap,
    this.onRowSecondaryTap,
    this.contextActions = const [],
    this.onRowChecked,
    this.onSelectAll,
    this.onDeleteShortcut,
    this.onEscapeShortcut,
    this.selectAllShortcut = 'Ctrl+A',
    this.deleteShortcut = 'Delete',
    this.escapeShortcut = 'Esc',
    this.verticalScrollController,
    this.showCheckboxes = false,
    this.autofocus = false,
    this.framed = true,
  });

  @override
  State<DataGridView<T>> createState() => _DataGridViewState<T>();
}

/// Mostra il menu contestuale della griglia nel punto indicato.
///
/// Riusabile da qualunque widget (righe `DataGridView` o card mobili):
/// costruisce il menu dalle [actions] e, alla selezione, esegue
/// l'`onSelected` dell'azione con il valore [value] della riga.
Future<void> showDataGridViewContextMenu<T>({
  required BuildContext context,
  required List<DataGridViewContextAction<T>> actions,
  required T value,
  required Offset globalPosition,
}) async {
  if (actions.isEmpty) return;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final selected = await showMenu<DataGridViewContextAction<T>>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final action in actions)
        PopupMenuItem<DataGridViewContextAction<T>>(
          value: action,
          child: Row(
            children: [
              Icon(action.icon),
              const SizedBox(width: 8),
              Text(action.label),
            ],
          ),
        ),
    ],
  );
  if (selected != null) {
    await selected.onSelected(value);
  }
}

class _DataGridRowVisualState extends ChangeNotifier {
  _DataGridRowVisualState(this.color, this.borderSide);

  Color? color;
  BorderSide borderSide;

  void update(Color? nextColor, BorderSide nextBorderSide) {
    if (color == nextColor && borderSide == nextBorderSide) return;
    color = nextColor;
    borderSide = nextBorderSide;
    notifyListeners();
  }
}

class _DataGridRowDecoration extends Decoration {
  const _DataGridRowDecoration(this.visualState);

  final _DataGridRowVisualState visualState;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _DataGridRowBoxPainter(visualState, onChanged);
  }
}

class _DataGridRowBoxPainter extends BoxPainter {
  _DataGridRowBoxPainter(this.visualState, this.onChanged) : super(onChanged) {
    visualState.addListener(_handleVisualChange);
  }

  final _DataGridRowVisualState visualState;
  final VoidCallback? onChanged;

  void _handleVisualChange() => onChanged?.call();

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final color = visualState.color;
    if (color != null) {
      canvas.drawRect(offset & size, Paint()..color = color);
    }
    final borderSide = visualState.borderSide;
    if (borderSide.style != BorderStyle.none && borderSide.width > 0) {
      final borderPaint = Paint()
        ..color = borderSide.color
        ..strokeWidth = borderSide.width;
      final y = offset.dy + borderSide.width / 2;
      canvas.drawLine(
        Offset(offset.dx, y),
        Offset(offset.dx + size.width, y),
        borderPaint,
      );
    }
  }

  @override
  void dispose() {
    visualState.removeListener(_handleVisualChange);
    super.dispose();
  }
}

class _DataGridViewState<T> extends State<DataGridView<T>> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'DataGridView');
  int? _selectedIndex;
  String? _selectedRowId;
  List<DataRow2>? _builtRows;
  List<DataGridViewRowData<T>>? _builtRowsSource;
  List<DataGridViewColumn>? _builtRowsColumns;
  Set<String> _builtRowsCheckedIds = const <String>{};
  Map<String, int> _builtRowIndexes = const <String, int>{};
  int? _builtRowsActiveIndex;
  bool? _builtRowsShowCheckboxes;
  bool? _builtRowsCanCheck;
  bool? _builtRowsCanSecondaryTap;
  List<_DataGridRowVisualState> _rowVisualStates = <_DataGridRowVisualState>[];
  int _builtRowsRevision = 0;
  Widget? _builtDataTable;
  int? _builtDataTableRowsRevision;
  ScrollController? _builtDataTableScrollController;
  double? _builtDataTableMaxWidth;
  double? _builtDataTableMinWidth;
  static const double _headingRowHeight = 46;
  static const double _dataRowHeight = 68;

  List<DataGridViewColumn> get _columns => widget.columns;

  List<DataGridViewRowData<T>> get _rows => widget.rows;

  bool get _hasRows => _rows.isNotEmpty;
  int? get _activeRowIndex => _selectedIndex;

  bool get _canSecondaryTap =>
      widget.onRowSecondaryTap != null || widget.contextActions.isNotEmpty;

  /// Ultimo punto toccato su una cella: la pressione prolungata non porta
  /// la posizione, e il menu va aperto dove si trova il dito.
  Offset _lastTapPosition = Offset.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _builtRows = null;
    _builtDataTable = null;
  }

  @override
  void didUpdateWidget(covariant DataGridView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rowsChanged = !identical(widget.rows, oldWidget.rows);
    if (widget.selectedRowId != oldWidget.selectedRowId) {
      final selectedRowId = widget.selectedRowId;
      if (selectedRowId == null || selectedRowId.isEmpty || _rows.isEmpty) {
        _selectedIndex = null;
        _selectedRowId = null;
      } else {
        final selectedIndex = _rows.indexWhere(
          (row) => row.id == selectedRowId,
        );
        _selectedIndex = selectedIndex == -1 ? null : selectedIndex;
        _selectedRowId = selectedIndex == -1 ? null : selectedRowId;
      }
    } else if (rowsChanged) {
      final selectedIndex = _selectedRowId == null
          ? -1
          : _rows.indexWhere((row) => row.id == _selectedRowId);
      if (selectedIndex != -1) {
        _selectedIndex = selectedIndex;
      } else {
        final selectedRowId = widget.selectedRowId;
        if (selectedRowId == null || selectedRowId.isEmpty || _rows.isEmpty) {
          _selectedIndex = null;
          _selectedRowId = null;
        } else {
          final parentSelectedIndex = _rows.indexWhere(
            (row) => row.id == selectedRowId,
          );
          _selectedIndex = parentSelectedIndex == -1
              ? null
              : parentSelectedIndex;
          _selectedRowId = parentSelectedIndex == -1 ? null : selectedRowId;
        }
      }
    }
    final selectedIndex = _selectedIndex;
    if (selectedIndex != null && selectedIndex >= _rows.length) {
      _selectedIndex = _rows.isEmpty ? null : _rows.length - 1;
      _selectedRowId = _selectedIndex == null
          ? null
          : _rows[_selectedIndex!].id;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_hasRows) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final selectedIndex = _activeRowIndex;
      final index = selectedIndex == null
          ? 0
          : (selectedIndex + 1).clamp(0, _rows.length - 1);
      _selectIndex(index);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final selectedIndex = _activeRowIndex;
      final index = selectedIndex == null
          ? 0
          : (selectedIndex - 1).clamp(0, _rows.length - 1);
      _selectIndex(index);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final selectedIndex = _activeRowIndex;
      if (selectedIndex == null) return KeyEventResult.ignored;
      widget.onRowDoubleTap?.call(_rows[selectedIndex].value);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      final selectedIndex = _activeRowIndex;
      if (!widget.showCheckboxes ||
          widget.onRowChecked == null ||
          selectedIndex == null) {
        return KeyEventResult.ignored;
      }
      final row = _rows[selectedIndex];
      widget.onRowChecked!(row.value, !widget.selectedRowIds.contains(row.id));
      if (!_focusNode.hasFocus) _focusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (_matchesShortcut(event, widget.selectAllShortcut)) {
      widget.onSelectAll?.call(true);
      if (!_focusNode.hasFocus) _focusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (_matchesShortcut(event, widget.deleteShortcut)) {
      final selectedIndex = _activeRowIndex;
      widget.onDeleteShortcut?.call(
        selectedIndex == null ? null : _rows[selectedIndex].value,
      );
      if (!_focusNode.hasFocus) _focusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (_matchesShortcut(event, widget.escapeShortcut)) {
      widget.onEscapeShortcut?.call();
      if (!_focusNode.hasFocus) _focusNode.requestFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _matchesShortcut(KeyEvent event, String shortcut) {
    final parts = shortcut
        .toLowerCase()
        .split('+')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet();
    if (parts.isEmpty) return false;

    final wantsCtrl = parts.remove('ctrl') || parts.remove('control');
    final wantsAlt = parts.remove('alt');
    final wantsShift = parts.remove('shift');
    final wantsMeta = parts.remove('meta') || parts.remove('cmd');

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed != wantsCtrl) return false;
    if (keyboard.isAltPressed != wantsAlt) return false;
    if (keyboard.isShiftPressed != wantsShift) return false;
    if (keyboard.isMetaPressed != wantsMeta) return false;

    if (parts.length != 1) return false;
    return _shortcutKeyName(event.logicalKey) == parts.single;
  }

  String _shortcutKeyName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.escape) return 'esc';
    if (key == LogicalKeyboardKey.delete) return 'delete';
    if (key == LogicalKeyboardKey.enter) return 'enter';
    final label = key.keyLabel.toLowerCase();
    if (label.length == 1) return label;
    return (key.debugName ?? '').toLowerCase().replaceAll(' ', '');
  }

  void _selectIndex(int index) {
    if (index < 0 || index >= _rows.length) return;
    final stopwatch = Stopwatch()..start();
    log.d(
      '[perf-trace] _selectIndex START idx=$index rowCount=${_rows.length}',
    );
    final previousIndex = _selectedIndex;
    _selectedIndex = index;
    _selectedRowId = _rows[index].id;
    if (previousIndex != index) {
      if (previousIndex != null) _refreshBuiltRow(previousIndex);
      _refreshBuiltRow(index);
      _builtRowsActiveIndex = index;
    }
    log.d(
      '[perf-trace] _selectIndex visual done dur=${stopwatch.elapsedMilliseconds}ms',
    );
    _ensureRowVisible(index);
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
    if (!mounted || index < 0 || index >= _rows.length) return;
    widget.onRowSelected?.call(_rows[index].value);
    log.d(
      '[perf-trace] _selectIndex DONE dur=${stopwatch.elapsedMilliseconds}ms',
    );
  }

  void _ensureRowVisible(int index) {
    final controller = widget.verticalScrollController;
    if (controller == null || !controller.hasClients) return;

    final position = controller.position;
    final rowTop = _headingRowHeight + index * _dataRowHeight;
    final rowBottom = rowTop + _dataRowHeight;
    final viewportTop = position.pixels;
    final viewportBottom = viewportTop + position.viewportDimension;

    if (rowTop >= viewportTop && rowBottom <= viewportBottom) return;

    final target = rowTop - (_dataRowHeight * 0.35);
    final maxScroll = position.maxScrollExtent;
    final safeTarget = target.clamp(position.minScrollExtent, maxScroll);
    controller.jumpTo(safeTarget);
  }

  Widget _cell(DataGridViewRowData<T> row, DataGridViewColumn column) {
    final child = row.cells[column.id] ?? const Text('-');
    final styledChild = row.foregroundColor == null
        ? child
        : DefaultTextStyle.merge(
            style: TextStyle(color: row.foregroundColor),
            child: IconTheme.merge(
              data: IconThemeData(color: row.foregroundColor),
              child: child,
            ),
          );
    return Align(
      alignment: column.numeric ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: styledChild,
      ),
    );
  }

  List<DataColumn2> _buildColumns() {
    final dataColumns = _columns
        .map(
          (column) => DataColumn2(
            label: Text(
              column.label.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            // Una colonna flessibile non ha larghezza fissa: e' lei che
            // incassa la larghezza residua del riquadro, cosi la tabella
            // arriva al bordo destro invece di lasciare uno spazio morto.
            // `width` resta il minimo, applicato dal tavolo solo quando la
            // tabella e' piu stretta di quanto la colonna richieda.
            fixedWidth: column.flexible ? null : column.width,
            minWidth: column.flexible ? column.width : null,
            numeric: column.numeric,
          ),
        )
        .toList();
    return dataColumns;
  }

  bool _sameColumns(
    List<DataGridViewColumn>? previous,
    List<DataGridViewColumn> current,
  ) {
    if (previous == null || previous.length != current.length) return false;
    for (var index = 0; index < current.length; index++) {
      final previousColumn = previous[index];
      final currentColumn = current[index];
      if (previousColumn.id != currentColumn.id ||
          previousColumn.label != currentColumn.label ||
          previousColumn.width != currentColumn.width ||
          previousColumn.numeric != currentColumn.numeric ||
          previousColumn.flexible != currentColumn.flexible) {
        return false;
      }
    }
    return true;
  }

  bool _sameCheckedIds(Set<String> previous, Set<String> current) {
    return previous.length == current.length &&
        previous.every(current.contains);
  }

  Color? _rowColor(int index) {
    final colors = context.colors;
    final row = _rows[index];
    if (index == _activeRowIndex) {
      return colors.selectedCardBackground.withValues(alpha: 0.90);
    }
    if (widget.selectedRowIds.contains(row.id)) {
      return colors.variantSelectedBackground.withValues(alpha: 0.78);
    }
    if (row.backgroundColor != null) return row.backgroundColor;
    if (index.isEven) {
      return colors.surfaceVariantColor.withValues(alpha: 0.35);
    }
    return null;
  }

  BorderSide _rowBorderSide() {
    return Divider.createBorderSide(context, width: 0.35);
  }

  void _updateRowVisual(int index) {
    _rowVisualStates[index].update(_rowColor(index), _rowBorderSide());
  }

  void _refreshBuiltRow(int index) {
    final builtRows = _builtRows;
    if (builtRows == null ||
        index < 0 ||
        index >= builtRows.length ||
        index >= _rowVisualStates.length) {
      return;
    }
    _updateRowVisual(index);
    builtRows[index] = _buildRow(index);
  }

  void _openContextMenu(int index, T value, TapDownDetails details) {
    if (widget.contextActions.isNotEmpty) {
      // Selezione della riga prima del menu (comportamento standard).
      _selectIndex(index);
      if (!mounted) return;
      showDataGridViewContextMenu(
        context: context,
        actions: widget.contextActions,
        value: value,
        globalPosition: details.globalPosition,
      );
    } else {
      widget.onRowSecondaryTap?.call(details, value);
    }
  }

  DataRow2 _buildRow(int index) {
    final row = _rows[index];
    final checked = widget.selectedRowIds.contains(row.id);
    final cells = _columns
        .map(
          (column) => DataCell(
            _cell(row, column),
            onTapDown: (details) {
              _lastTapPosition = details.globalPosition;
              _selectIndex(index);
            },
            onTap: widget.onRowTap == null
                ? null
                : () => widget.onRowTap!(row.value),
          ),
        )
        .toList();
    return DataRow2(
      selected: checked,
      onSelectChanged: widget.showCheckboxes && widget.onRowChecked != null
          ? (value) => widget.onRowChecked!(row.value, value ?? false)
          : null,
      decoration: _DataGridRowDecoration(_rowVisualStates[index]),
      onDoubleTap: () => widget.onRowDoubleTap?.call(row.value),
      onSecondaryTapDown: !_canSecondaryTap
          ? null
          : (details) => _openContextMenu(index, row.value, details),
      // Su touch non esiste il tasto destro: la pressione prolungata apre
      // lo stesso menu, altrimenti le azioni di riga sarebbero irraggiungibili.
      onLongPress: !_canSecondaryTap
          ? null
          : () => _openContextMenu(
              index,
              row.value,
              TapDownDetails(globalPosition: _lastTapPosition),
            ),
      cells: cells,
    );
  }

  List<DataRow2> _rebuildAllRows() {
    final borderSide = _rowBorderSide();
    _rowVisualStates = List<_DataGridRowVisualState>.generate(
      _rows.length,
      (index) => _DataGridRowVisualState(_rowColor(index), borderSide),
    );
    final rows = List<DataRow2>.generate(_rows.length, _buildRow);
    _builtRows = rows;
    _builtRowsSource = _rows;
    _builtRowsColumns = List<DataGridViewColumn>.of(_columns);
    _builtRowsCheckedIds = Set<String>.of(widget.selectedRowIds);
    _builtRowIndexes = <String, int>{
      for (var index = 0; index < _rows.length; index++) _rows[index].id: index,
    };
    _builtRowsActiveIndex = _activeRowIndex;
    _builtRowsShowCheckboxes = widget.showCheckboxes;
    _builtRowsCanCheck = widget.onRowChecked != null;
    _builtRowsCanSecondaryTap = _canSecondaryTap;
    _builtRowsRevision++;
    return rows;
  }

  List<DataRow2> _buildRows() {
    final builtRows = _builtRows;
    final columnsChanged = !_sameColumns(_builtRowsColumns, _columns);
    final rowConfigurationChanged =
        _builtRowsShowCheckboxes != widget.showCheckboxes ||
        _builtRowsCanCheck != (widget.onRowChecked != null) ||
        _builtRowsCanSecondaryTap != _canSecondaryTap;
    if (builtRows == null ||
        builtRows.length != _rows.length ||
        columnsChanged ||
        rowConfigurationChanged) {
      return _rebuildAllRows();
    }

    final changedIndexes = <int>{};
    var tableRowsChanged = false;
    if (!identical(_builtRowsSource, _rows)) {
      final previousRows = _builtRowsSource!;
      for (var index = 0; index < _rows.length; index++) {
        if (previousRows[index].id != _rows[index].id) {
          return _rebuildAllRows();
        }
        if (!identical(previousRows[index], _rows[index])) {
          changedIndexes.add(index);
          tableRowsChanged = true;
        }
      }
    }

    if (!_sameCheckedIds(_builtRowsCheckedIds, widget.selectedRowIds)) {
      tableRowsChanged = true;
      for (final id in _builtRowsCheckedIds) {
        if (!widget.selectedRowIds.contains(id)) {
          final index = _builtRowIndexes[id];
          if (index != null) changedIndexes.add(index);
        }
      }
      for (final id in widget.selectedRowIds) {
        if (!_builtRowsCheckedIds.contains(id)) {
          final index = _builtRowIndexes[id];
          if (index != null) changedIndexes.add(index);
        }
      }
    }

    final activeRowIndex = _activeRowIndex;
    if (_builtRowsActiveIndex != activeRowIndex) {
      final previousActiveRowIndex = _builtRowsActiveIndex;
      if (previousActiveRowIndex != null &&
          previousActiveRowIndex < _rows.length) {
        changedIndexes.add(previousActiveRowIndex);
      }
      if (activeRowIndex != null) changedIndexes.add(activeRowIndex);
    }

    for (final index in changedIndexes) {
      _refreshBuiltRow(index);
    }
    _builtRowsSource = _rows;
    _builtRowsCheckedIds = Set<String>.of(widget.selectedRowIds);
    _builtRowsActiveIndex = activeRowIndex;
    if (tableRowsChanged) _builtRowsRevision++;
    return builtRows;
  }

  Widget _buildDataTable({
    required BoxConstraints constraints,
    required ThemeData theme,
    required double tableMinWidth,
    required double columnSpacing,
    required double horizontalMargin,
  }) {
    final rows = _buildRows();
    final checkboxTheme = CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return theme.colorScheme.primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(theme.colorScheme.onPrimary),
      side: BorderSide(color: theme.colorScheme.outline),
    );
    final builtDataTable = _builtDataTable;
    if (builtDataTable != null &&
        _builtDataTableRowsRevision == _builtRowsRevision &&
        identical(
          _builtDataTableScrollController,
          widget.verticalScrollController,
        ) &&
        _builtDataTableMaxWidth == constraints.maxWidth &&
        _builtDataTableMinWidth == tableMinWidth) {
      return builtDataTable;
    }

    final dataTable = DataTable2(
      scrollController: widget.verticalScrollController,
      columnSpacing: columnSpacing,
      horizontalMargin: horizontalMargin,
      minWidth: tableMinWidth,
      headingRowHeight: _headingRowHeight,
      dataRowHeight: _dataRowHeight,
      showCheckboxColumn: widget.showCheckboxes,
      headingCheckboxTheme: checkboxTheme,
      datarowCheckboxTheme: checkboxTheme,
      onSelectAll: widget.showCheckboxes
          ? (value) => widget.onSelectAll?.call(value ?? false)
          : null,
      fixedTopRows: 1,
      isHorizontalScrollBarVisible: tableMinWidth > constraints.maxWidth,
      headingRowColor: WidgetStatePropertyAll(
        context.colors.headerGradientStart.withValues(alpha: 0.10),
      ),
      dividerThickness: 0.35,
      columns: _buildColumns(),
      rows: rows,
    );
    _builtDataTable = dataTable;
    _builtDataTableRowsRevision = _builtRowsRevision;
    _builtDataTableScrollController = widget.verticalScrollController;
    _builtDataTableMaxWidth = constraints.maxWidth;
    _builtDataTableMinWidth = tableMinWidth;
    return dataTable;
  }

  /// La tabella col [LayoutBuilder] che le fornisce i vincoli reali: senza
  /// cornice riceve tutta la larghezza disponibile, con cornice riceve
  /// l'interno del riquadro decorato.
  Widget _buildTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildDataTable(
          constraints: constraints,
          theme: Theme.of(context),
          tableMinWidth: _tableMinWidth(),
          columnSpacing: _columnSpacing,
          horizontalMargin: _horizontalMargin,
        );
      },
    );
  }

  static const double _columnSpacing = 12.0;
  static const double _horizontalMargin = 12.0;

  double _tableMinWidth() {
    final columnCount = _columns.length;
    final fixedColumnsWidth = _columns.fold<double>(
      0,
      (sum, col) => sum + col.width,
    );
    // DataTable2 riserva spazio anche alla colonna checkbox (che noi non
    // dichiariamo in `columns`) e sottrae dal `minWidth` un blocco
    // `3 * horizontalMargin + Checkbox.width` prima di verificare il suo
    // assert "combined width of columns of fixed width is greater than
    // availble parent width". Se il `minWidth` non comprende anche quella
    // colonna, l'assert scatta su schermi stretti con poche colonne (caso
    // smartphone: 2 colonne => 390 < 368) e la griglia rende un box vuoto a
    // ogni frame. Aggiungiamo quindi lo spazio riservato al checkbox più 1px
    // di sicurezza: l'assert passa per qualsiasi numero di colonne.
    final checkboxColumnWidth = widget.showCheckboxes
        ? _horizontalMargin * 1.5 + Checkbox.width
        : 0.0;
    return fixedColumnsWidth +
        (_horizontalMargin * 2) +
        (_columnSpacing * (columnCount > 1 ? columnCount - 1 : 0)) +
        checkboxColumnWidth +
        1.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: widget.framed
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: colors.dividerColor),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadowColor.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _buildTable(),
                    ),
                  )
                : _buildTable(),
          ),
        ],
      ),
    );
  }
}
