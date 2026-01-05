// lib/pages/map_page.dart
//
// Map + location manager / picker for Private Memo.
// - Single tap to choose a coordinate (no longer long-press).
// - Bottom-right shows the resolved place name for the tapped coordinate.
// - Bottom-right "Add" button saves the tapped coordinate as a LocationPoint.
// - If user doesn't enter a custom label, we try to use the map's own place name via reverse geocoding (Nominatim).
// - Users can also tap an existing saved marker and "Use this location" to return it to the caller.
//
// IMPORTANT:
// This file uses Nominatim reverse geocoding, so you must add to pubspec.yaml:
//   http: ^1.2.0
//
// And run: flutter pub get

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../models/location_point.dart';
import '../repositories/location_repository.dart';
import '../repositories/memo_repository.dart';

class MapPage extends StatefulWidget {
  final int userId;

  /// MapPage is used as a location picker. When user confirms, it can return a LocationPoint.
  /// We keep constructor signature minimal to match your current project usage.
  const MapPage({super.key, required this.userId});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _repo = LocationRepository();
  final _memoRepo = MemoRepository();

  // Locations created in this MapPage session (not yet linked to a memo).
  final Set<int> _sessionPointIds = <int>{};

  final _mapController = MapController();

  bool _loading = false;
  bool _locating = false;

  // Map view state
  LatLng _center = const LatLng(3.1390, 101.6869); // default: Kuala Lumpur-ish
  double _zoom = 15;

  // Saved points from DB
  List<LocationPoint> _points = [];

  // Current selection (either an existing saved point OR a tapped coordinate)
  LocationPoint? _selectedSavedPoint;
  LatLng? _pickedLatLng;

  // Resolved name for _pickedLatLng (reverse geocoded)
  bool _resolvingName = false;
  String? _pickedPlaceName;

  @override
  void initState() {
    super.initState();
    _loadPoints();
    _goToMyLocation(); // best effort
  }

  Future<void> _loadPoints() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getPointsByUser(widget.userId);

      // Only keep markers that are still referenced by existing memos
      // (so pins from "removed" locations won't stay on the picker map).
      final memos = await _memoRepo.getMemosByUser(widget.userId);
      final activeIds = memos
          .where((m) => m.locationId != null)
          .map((m) => m.locationId!)
          .toSet();

      // Keep session-created points & currently selected point visible too.
      activeIds.addAll(_sessionPointIds);
      final selectedId = _selectedSavedPoint?.id;
      if (selectedId != null) activeIds.add(selectedId);

      final filtered = list.where((p) {
        final id = p.id;
        if (id == null) return false;
        return activeIds.contains(id);
      }).toList();

      if (!mounted) return;
      setState(() {
        _points = filtered;
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
        throw Exception('Location service is disabled');
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final here = LatLng(pos.latitude, pos.longitude);
      _flyTo(here, 17);
    } catch (e) {
      _showSnack('$e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _flyTo(LatLng target, double zoom) {
    setState(() {
      _center = target;
      _zoom = zoom;
    });
    _mapController.move(target, zoom);
  }

  // ---------- New interaction: single tap chooses a coordinate ----------
  void _onMapTap(LatLng latLng) {
    setState(() {
      _pickedLatLng = latLng;
      _selectedSavedPoint = null; // switching to a new temp pick
      _pickedPlaceName = null;
    });
    _resolvePickedName(latLng);
  }

  Future<void> _resolvePickedName(LatLng latLng) async {
    // Reverse geocode via Nominatim (OpenStreetMap).
    // If it fails, we will fallback to coordinates.
    setState(() => _resolvingName = true);

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': latLng.latitude.toString(),
        'lon': latLng.longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
      });

      final resp = await http.get(
        uri,
        headers: {
          // Nominatim requires a User-Agent / Referer identifying the app
          'User-Agent': 'private-memo-swe311/1.0',
          'Accept-Language': 'en',
        },
      );

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final name = (data['name'] as String?)?.trim();
        final display = (data['display_name'] as String?)?.trim();

        // Prefer "name" if present, else display_name
        final resolved = (name != null && name.isNotEmpty) ? name : display;

        if (!mounted) return;
        // Only apply if user hasn't tapped elsewhere in the meantime
        if (_pickedLatLng?.latitude == latLng.latitude &&
            _pickedLatLng?.longitude == latLng.longitude) {
          setState(() => _pickedPlaceName = resolved);
        }
      }
    } catch (_) {
      // ignore; fallback later
    } finally {
      if (mounted) setState(() => _resolvingName = false);
    }
  }

  String _fallbackCoordsLabel(LatLng p) {
    return 'Lat ${p.latitude.toStringAsFixed(4)}, Lng ${p.longitude.toStringAsFixed(4)}';
  }

  Future<String?> _askCustomLabel() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location name (optional)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Custom name',
            hintText: 'Leave empty to use place name',
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return res;
  }

  Future<void> _addPickedPoint() async {
    final latLng = _pickedLatLng;
    if (latLng == null) {
      _showSnack('Tap the map to pick a location first.');
      return;
    }

    final custom = await _askCustomLabel();
    if (custom == null) return; // user cancelled dialog

    // If user didn't type a name, use reverse-geocoded name; fallback to coordinates
    final resolved = custom.trim().isNotEmpty
        ? custom.trim()
        : ((_pickedPlaceName ?? '').trim().isNotEmpty
            ? _pickedPlaceName!.trim()
            : _fallbackCoordsLabel(latLng));

    try {
      final newId = await _repo.createPoint(
        userId: widget.userId,
        lat: latLng.latitude,
        lng: latLng.longitude,
        label: resolved,
      );

      // Build a LocationPoint object to return to MemoFormPage
      final now = DateTime.now().toUtc().toIso8601String();
      final saved = LocationPoint(
        id: newId,
        userId: widget.userId,
        lat: latLng.latitude,
        lng: latLng.longitude,
        label: resolved,
        createdAt: now,
      );

      // Track this point in current session so it stays visible even before
      // it is linked to a memo.
      _sessionPointIds.add(newId);

      // Refresh list for marker display
      await _loadPoints();

      if (!mounted) return;
      setState(() {
        _selectedSavedPoint = saved;
        _pickedLatLng = null;
        _pickedPlaceName = null;
      });

      _showSnack('Location saved');

      // As a picker page, after adding we return it to the caller (memo form).
      Navigator.pop(context, saved);
    } catch (e) {
      _showSnack('Save failed: $e');
    }
  }

  Future<void> _deletePoint(LocationPoint p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete location?'),
        content: Text(
            'Delete "${(p.label ?? '').isEmpty ? 'this location' : p.label}"?'),
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
      if (!mounted) return;
      if (_selectedSavedPoint?.id == p.id) {
        setState(() => _selectedSavedPoint = null);
      }
      _showSnack('Deleted');
    } catch (e) {
      _showSnack('Delete failed: $e');
    }
  }

  void _useSelectedSavedPoint() {
    final p = _selectedSavedPoint;
    if (p == null) {
      _showSnack('Select a saved marker first.');
      return;
    }
    Navigator.pop(context, p);
  }

  void _onMarkerTap(LocationPoint p) {
    setState(() {
      _selectedSavedPoint = p;
      _pickedLatLng = null;
      _pickedPlaceName = null;
    });

    // Fly a bit closer for feedback
    _flyTo(LatLng(p.lat, p.lng), math.max(_zoom, 16));
  }

  List<Marker> _buildMarkers(ThemeData theme) {
    final markers = <Marker>[];

    // Saved markers
    for (final p in _points) {
      if (p.id == null) continue;
      markers.add(
        Marker(
          point: LatLng(p.lat, p.lng),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => _onMarkerTap(p),
            child: Icon(
              Icons.place,
              size: 40,
              color: (_selectedSavedPoint?.id == p.id)
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
        ),
      );
    }

    // Temporary picked marker
    final picked = _pickedLatLng;
    if (picked != null) {
      markers.add(
        Marker(
          point: picked,
          width: 36,
          height: 36,
          child: Icon(
            Icons.location_on,
            size: 34,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    return markers;
  }

  // Bottom-right overlay text showing place name
  Widget _pickedNameOverlay(BuildContext context) {
    final theme = Theme.of(context);

    String? text;
    if (_selectedSavedPoint != null) {
      final t = (_selectedSavedPoint!.label ?? '').trim();
      text = t.isNotEmpty
          ? t
          : _fallbackCoordsLabel(
              LatLng(_selectedSavedPoint!.lat, _selectedSavedPoint!.lng));
    } else if (_pickedLatLng != null) {
      final t = (_pickedPlaceName ?? '').trim();
      text = t.isNotEmpty ? t : _fallbackCoordsLabel(_pickedLatLng!);
    } else {
      text = null;
    }

    if (text == null) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _resolvingName ? 'Loading place name…' : text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Optional: a small sheet for saved point actions
  void _showSavedPointActions(LocationPoint p) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (p.label ?? '').trim().isEmpty
                    ? 'Saved location'
                    : p.label!.trim(),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Lat: ${p.lat.toStringAsFixed(6)}\nLng: ${p.lng.toStringAsFixed(6)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context, p);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Use this location'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: () {
                      Navigator.pop(context);
                      _deletePoint(p);
                    },
                    icon: const Icon(Icons.delete_outline),
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
        title: const Text('Select Location'),
        actions: [
          IconButton(
            tooltip: 'My location',
            onPressed: _goToMyLocation,
            icon: Icon(
                _locating ? Icons.my_location : Icons.my_location_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_pickedLatLng == null) ? null : _addPickedPoint,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoom,
              // ✅ change: single tap to pick a point
              onTap: (tapPos, latLng) => _onMapTap(latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.private_memo',
              ),
              MarkerLayer(markers: _buildMarkers(theme)),
            ],
          ),

          // Top-left loading indicator
          if (_loading)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Loading…'),
                  ],
                ),
              ),
            ),

          // Bottom-right: place name (your requested "right bottom show name")
          Positioned(
            right: 16,
            bottom: 92,
            child: _pickedNameOverlay(context),
          ),

          // Bottom-center: quick use button for saved marker
          if (_selectedSavedPoint != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: FilledButton.icon(
                onPressed: () => _showSavedPointActions(_selectedSavedPoint!),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Use selected saved location'),
              ),
            ),
        ],
      ),
    );
  }
}
