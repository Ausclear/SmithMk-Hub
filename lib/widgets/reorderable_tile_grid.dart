import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/smithmk_theme.dart';

class TileData {
  final String id;
  final IconData icon;
  final String label;
  final String value;
  final Color activeColor;
  final bool isActive;

  const TileData({
    required this.id,
    required this.icon,
    required this.label,
    required this.value,
    this.activeColor = SmithMkColors.accent,
    this.isActive = false,
  });
}

class ReorderableTileGrid extends StatefulWidget {
  final List<TileData> tiles;
  final Function(List<TileData>) onReorder;
  final Function(TileData)? onTileTap;

  const ReorderableTileGrid({
    super.key,
    required this.tiles,
    required this.onReorder,
    this.onTileTap,
  });

  @override
  State<ReorderableTileGrid> createState() => _ReorderableTileGridState();
}

class _ReorderableTileGridState extends State<ReorderableTileGrid> {
  int? _dragIndex;
  int? _hoverIndex;
  Offset _dragOffset = Offset.zero;
  late List<TileData> _tiles;
  final List<GlobalKey> _keys = [];

  int _lastHapticIndex = -1;

  @override
  void initState() {
    super.initState();
    _tiles = List.from(widget.tiles);
    _updateKeys();
  }

  @override
  void didUpdateWidget(ReorderableTileGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tiles != widget.tiles) {
      _tiles = List.from(widget.tiles);
      _updateKeys();
    }
  }

  void _updateKeys() {
    _keys.clear();
    for (var i = 0; i < _tiles.length; i++) {
      _keys.add(GlobalKey());
    }
  }

  int _getGridIndex(Offset globalPos) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return -1;
    final localPos = box.globalToLocal(globalPos);
    final width = box.size.width;
    final tileWidth = (width - 12) / 2;
    final tileHeight = tileWidth / 1.4;
    final col = (localPos.dx / (tileWidth + 12)).floor().clamp(0, 1);
    final row = (localPos.dy / (tileHeight + 12)).floor().clamp(0, (_tiles.length / 2).ceil() - 1);
    final index = row * 2 + col;
    return index.clamp(0, _tiles.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 12) / 2;
        final tileHeight = tileWidth / 1.4;

        return SizedBox(
          height: ((_tiles.length / 2).ceil()) * (tileHeight + 12) - 12,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background tiles (non-dragging)
              for (int i = 0; i < _tiles.length; i++)
                if (i != _dragIndex)
                  AnimatedPositioned(
                    duration: _dragIndex != null
                        ? const Duration(milliseconds: 200)
                        : Duration.zero,
                    curve: Curves.easeOutCubic,
                    left: (i % 2) * (tileWidth + 12),
                    top: (i ~/ 2) * (tileHeight + 12),
                    width: tileWidth,
                    height: tileHeight,
                    child: _buildTile(i, tileWidth, tileHeight),
                  ),
              // Dragging tile (rendered last, on top)
              if (_dragIndex != null)
                Positioned(
                  left: (_dragIndex! % 2) * (tileWidth + 12) + _dragOffset.dx,
                  top: (_dragIndex! ~/ 2) * (tileHeight + 12) + _dragOffset.dy,
                  width: tileWidth,
                  height: tileHeight,
                  child: Transform.scale(
                    scale: 1.05,
                    child: _buildDragTile(_dragIndex!, tileWidth, tileHeight),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTile(int index, double width, double height) {
    final tile = _tiles[index];
    final isHoverTarget = _hoverIndex == index && _dragIndex != null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTileTap?.call(tile);
      },
      onLongPressStart: (details) {
        HapticFeedback.mediumImpact();
        setState(() {
          _dragIndex = index;
          _dragOffset = Offset.zero;
          _lastHapticIndex = index;
        });
      },
      onLongPressMoveUpdate: (details) {
        setState(() {
          _dragOffset += details.offsetFromOrigin - _dragOffset;
          _dragOffset = details.offsetFromOrigin;
        });
        final newHover = _getGridIndex(details.globalPosition);
        if (newHover != _hoverIndex && newHover != _dragIndex) {
          if (newHover != _lastHapticIndex) {
            HapticFeedback.selectionClick();
            _lastHapticIndex = newHover;
          }
          setState(() {
            if (_hoverIndex != null && _dragIndex != null) {
              final item = _tiles.removeAt(_dragIndex!);
              _tiles.insert(newHover, item);
              _dragIndex = newHover;
              _dragOffset = Offset.zero;
            }
            _hoverIndex = newHover;
          });
        }
      },
      onLongPressEnd: (details) {
        HapticFeedback.mediumImpact();
        setState(() {
          _dragIndex = null;
          _hoverIndex = null;
          _dragOffset = Offset.zero;
        });
        widget.onReorder(_tiles);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isHoverTarget
              ? SmithMkColors.accent.withValues(alpha: 0.08)
              : Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHoverTarget
                ? SmithMkColors.accent.withValues(alpha: 0.3)
                : SmithMkColors.glassBorder,
            width: isHoverTarget ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: _buildTileContent(tile),
      ),
    );
  }

  Widget _buildDragTile(int index, double width, double height) {
    final tile = _tiles[index];
    return Container(
      decoration: BoxDecoration(
        color: SmithMkColors.cardSurfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SmithMkColors.accent.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: SmithMkColors.accent.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: _buildTileContent(tile),
    );
  }

  Widget _buildTileContent(TileData tile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (tile.isActive ? tile.activeColor : SmithMkColors.textTertiary)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                tile.icon,
                color: tile.isActive ? tile.activeColor : SmithMkColors.textTertiary,
                size: 22,
              ),
            ),
            if (tile.isActive)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tile.activeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tile.activeColor.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const Spacer(),
        Text(
          tile.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: SmithMkColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          tile.value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: tile.isActive ? SmithMkColors.textPrimary : SmithMkColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
