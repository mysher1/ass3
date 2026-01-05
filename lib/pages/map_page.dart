// lib/pages/map_page.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/location_point.dart';
import '../repositories/location_repository.dart';

class MapPage extends StatefulWidget {
  final int userId;
  const MapPage({super.key, required this.userId});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _repo = LocationRepository();
  final _mapController = MapController();

  bool _loading = true;
  bool _locating = false;

  List<LocationPoint> _points = [];

  // Default: Kuala Lumpur-ish (since you said Malaysia)
  LatLng _center = const LatLng(3.1390, 101.6869);
  double _zoom = 13;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getPointsByUser(widget.userId);
      if (!mounted) return;
      setState(() {
        _points = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('Load failed: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('Location service is disabled.');
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
      if (perm == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied.');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final me = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _center = me;
        _zoom = math.max(_zoom, 16);
      });

      _mapController.move(_center, _zoom);
    } catch (e) {
      _showSnack('Location failed: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addPointAt(LatLng p) async {
    final label = await _askLabel();
    if (!mounted) return;

    try {
      await _repo.createPoint(
        userId: widget.userId,
        lat: p.latitude,
        lng: p.longitude,
        label: (label ?? ''),
      );
      await _loadPoints();
      _showSnack('Saved');
    } catch (e) {
      _showSnack('Save failed: $e');
    }
  }

  Future<String?> _askLabel() async {
    final ctrl = TextEditingController();
    final theme = Theme.of(context);

    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save location'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Label (optional)',
            hintText: 'e.g. Home, Cafe, Parking',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // avoid unused theme warning in some setups
    // ignore: unnecessary_statements
    theme;

    return res;
  }

  Future<void> _deletePoint(LocationPoint p) async {
    if (p.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this location?'),
        content: Text(
          'This will delete "${(p.label ?? 'Untitled').trim().isEmpty ? 'Untitled' : p.label}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _repo.deletePoint(pointId: p.id!, userId: widget.userId);
      await _loadPoints();
      _showSnack('Deleted');
    } catch (e) {
      _showSnack('Delete failed: $e');
    }
  }

  void _flyToPoint(LocationPoint p) {
    final latLng = LatLng(p.lat, p.lng);
    _mapController.move(latLng, math.max(_zoom, 16));
  }

  List<Marker> _buildMarkers(ThemeData theme) {
    return _points.map((p) {
      return Marker(
        point: LatLng(p.lat, p.lng),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _openPointSheet(p),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.95),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: theme.colorScheme.surface, width: 3),
              boxShadow: [
                BoxShadow(
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                  color: Colors.black.withOpacity(0.18),
                ),
              ],
            ),
            child: Icon(
              Icons.place_rounded,
              color: theme.colorScheme.onPrimary,
              size: 22,
            ),
          ),
        ),
      );
    }).toList();
  }

  void _openPointSheet(LocationPoint p) {
    final theme = Theme.of(context);
    final title =
        (p.label ?? '').trim().isEmpty ? 'Untitled' : (p.label!).trim();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Lat: ${p.lat.toStringAsFixed(6)}\nLng: ${p.lng.toStringAsFixed(6)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _flyToPoint(p);
                      },
                      icon: const Icon(Icons.my_location_rounded),
                      label: const Text('Go to'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deletePoint(p);
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            tooltip: 'My location',
            onPressed: _locating ? null : _goToMyLocation,
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadPoints,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoom,
              onLongPress: (tapPos, latLng) => _addPointAt(latLng),
            ),
            children: [
              TileLayer(
                // OpenStreetMap tiles
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.private_memo',
              ),
              MarkerLayer(markers: _buildMarkers(theme)),
            ],
          ),

          // a small hint overlay
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.95,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tip: Long-press on the map to save a location.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_loading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
