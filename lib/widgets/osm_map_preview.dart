import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

class OsmMapPreview extends StatelessWidget {
  const OsmMapPreview({
    required this.label,
    this.latitude,
    this.longitude,
    this.height = 180,
    this.zoom = 14,
    this.approximate = false,
    this.showMarker = true,
    super.key,
  });

  static const tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const tileHeaders = {
    'User-Agent': 'Property24Zimbabwe/1.0 (+https://property24.local)',
  };

  final String label;
  final num? latitude;
  final num? longitude;
  final double height;
  final int zoom;
  final bool approximate;
  final bool showMarker;

  bool get _hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          border: Border.all(color: AppTheme.border),
        ),
        child: _hasCoordinates
            ? _TileMap(
                label: label,
                latitude: latitude!.toDouble(),
                longitude: longitude!.toDouble(),
                zoom: zoom,
                approximate: approximate,
                showMarker: showMarker,
              )
            : _MapPlaceholder(label: label),
      ),
    );
  }
}

class _TileMap extends StatelessWidget {
  const _TileMap({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.approximate,
    required this.showMarker,
  });

  final String label;
  final double latitude;
  final double longitude;
  final int zoom;
  final bool approximate;
  final bool showMarker;

  static const _tileSize = 256.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final center = _worldPixel(latitude, longitude, zoom);
        final topLeft = Offset(
          center.dx - constraints.maxWidth / 2,
          center.dy - constraints.maxHeight / 2,
        );
        final firstTileX = (topLeft.dx / _tileSize).floor();
        final firstTileY = (topLeft.dy / _tileSize).floor();
        final columns = (constraints.maxWidth / _tileSize).ceil() + 2;
        final rows = (constraints.maxHeight / _tileSize).ceil() + 2;
        final maxTile = math.pow(2, zoom).toInt();

        return Stack(
          children: [
            for (var row = 0; row < rows; row++)
              for (var column = 0; column < columns; column++)
                Positioned(
                  left: (firstTileX + column) * _tileSize - topLeft.dx,
                  top: (firstTileY + row) * _tileSize - topLeft.dy,
                  width: _tileSize,
                  height: _tileSize,
                  child: Image.network(
                    _tileUrl(
                      zoom,
                      _wrapTile(firstTileX + column, maxTile),
                      (firstTileY + row).clamp(0, maxTile - 1),
                    ),
                    headers: OsmMapPreview.tileHeaders,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.bgSurface,
                    ),
                  ),
                ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.18),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            if (showMarker)
              Center(
                child: Container(
                  height: approximate ? 54 : 42,
                  width: approximate ? 54 : 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withOpacity(0.16),
                    border: Border.all(
                      color: AppTheme.accent.withOpacity(0.28),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      height: 16,
                      width: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _MapLabel(
                      label: label,
                      prefix: approximate ? 'Approximate area' : 'Exact area',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _Attribution(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static Offset _worldPixel(double latitude, double longitude, int zoom) {
    final scale = math.pow(2, zoom) * _tileSize;
    final lat = latitude.clamp(-85.05112878, 85.05112878);
    final sinLat = math.sin(lat * math.pi / 180);
    final x = (longitude + 180) / 360 * scale;
    final y =
        (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
    return Offset(x, y);
  }

  static int _wrapTile(int tile, int maxTile) {
    return ((tile % maxTile) + maxTile) % maxTile;
  }

  static String _tileUrl(int zoom, int x, int y) {
    return OsmMapPreview.tileUrlTemplate
        .replaceAll('{z}', '$zoom')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _MapPatternPainter(),
          ),
        ),
        Center(
          child: _MapLabel(
            label: label,
            prefix: 'Area only',
          ),
        ),
        const Positioned(
          right: 10,
          bottom: 10,
          child: _Attribution(),
        ),
      ],
    );
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({
    required this.label,
    required this.prefix,
  });

  final String label;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.location,
            color: AppTheme.accent,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label.isEmpty ? prefix : '$prefix: $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Text(
        '© OpenStreetMap',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.borderMid.withOpacity(0.36)
      ..strokeWidth = 1;
    for (var i = 0; i < 8; i++) {
      final y = size.height * (i + 1) / 9;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + (i.isEven ? 18 : -18)),
        paint,
      );
    }
    for (var i = 0; i < 6; i++) {
      final x = size.width * (i + 1) / 7;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + (i.isEven ? -12 : 12), size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
