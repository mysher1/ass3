// lib/pages/map_page.dart
//
// OpenStreetMap (via flutter_map) page.
// Supports two modes:
// 1) Manage mode (default): view/add/delete saved locations for the user.
// 2) Select mode: pick a location for a memo and return it via Navigator.pop().
//
// Returned value in select mode:
// - Existing saved location: LocationPoint
// - New location created from map tap: LocationPoint (saved to DB first)

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../db/app_database.dart';
import '../models/location_point.dart';
import '../repositories/location_repository.dart';

class MapPage extends StatefulWidget {
  final int userId;

  /// If true, user can pick a location and this page will `pop()` a LocationPoint.
  final bool selectMode;

  /// Optional: pre-select a saved location when opening the page.
  final int? initialSelectedLocationId;

  const MapPage({
    super.key,
    required this.userId,
    this.selectMode = false,
    this.initialSelectedLocationId,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final LocationRepository _repo;
  final MapController _mapController = MapController();

  bool _loading = true;
  bool _locating = false;

  List<LocationPoint> _points = [];

  // Default center: Kuala Lumpur-ish
  LatLng _center = const LatLng(3.1390, 101.6869);
  double _zoom = 13;

  // Selection / creation state
  LocationPoint? _selectedSavedPoint;
  LatLng? _tempPickedLatLng; // picked on map but not saved yet

  @override
  void initState() {
    super.initState();
    _repo = LocationRepository(AppDatabase.instance);
    _init();
  }

  Future<void> _init() async {
    await _refreshPoints();

    // Try to preselect if requested
    if (widget.initialSelectedLocationId != null) {
      final match = _points
          .where((p) => p.id == widget.initialSelectedLocationId)
          .toList();
      if (match.isNotEmpty) {
        _selectedSavedPoint = match.first;
        _center = LatLng(_selectedSavedPoint!.lat, _selectedSavedPoint!.lng);
        _zoom = 15;
      }
    }

    // Try to move to current position, but don't block the screen
    // (especially important if permission is denied).
    _moveToCurrentPosition(silent: true);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshPoints() async {
    final res = await _repo.getLocationsByUser(widget.userId);
    if (!mounted) return;
    setState(() {
      _points = res;
    });
  }

  Future<void> _deletePoint(LocationPoint p) async {
    if (p.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this location?'),
        content: Text('This will delete "${p.displayLabel}".'),
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

    await _repo.deleteLocation(p.id!);
    if (_selectedSavedPoint?.id == p.id) _selectedSavedPoint = null;

    await _refreshPoints();
    if (mounted) setState(() {});
  }

  Future<String?> _askLabel({String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Library / Home / KLCC',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              Navigator.pop(ctx, v.isEmpty ? null : v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return res;
  }

  Future<void> _moveToCurrentPosition({bool silent = false}) async {
    try {
      if (!silent) setState(() => _locating = true);

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final here = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;
      setState(() {
        _center = here;
        _zoom = 16;
      });

      _mapController.move(here, _zoom);
    } catch (_) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get current location.')),
        );
      }
    } finally {
      if (!silent && mounted) setState(() => _locating = false);
    }
  }

  Future<void> _createLocationAt(LatLng latLng) async {
    final label = await _askLabel();
    if (label == null) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final point = LocationPoint(
      id: null,
      userId: widget.userId,
      lat: latLng.latitude,
      lng: latLng.longitude,
      label: label,
      createdAt: now,
    );

    final newId = await _repo.createLocation(point);
    final saved = point.copyWith(id: newId);

    await _refreshPoints();

    if (!mounted) return;
    setState(() {
      _selectedSavedPoint = saved;
      _tempPickedLatLng = null;
    });

    // In select mode, you may want to immediately return after creating:
    // but it's nicer UX to let them confirm. We'll keep it selected.
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    if (!widget.selectMode) {
      // In manage mode, tap creates a new location.
      _createLocationAt(latLng);
      return;
    }

    // In select mode, tap picks a temp location (not saved yet)
    setState(() {
      _tempPickedLatLng = latLng;
      _selectedSavedPoint = null;
    });
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final p in _points) {
      final isSelected =
          _selectedSavedPoint?.id != null && _selectedSavedPoint!.id == p.id;

      markers.add(
        Marker(
          point: LatLng(p.lat, p.lng),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedSavedPoint = p;
                _tempPickedLatLng = null;
              });
            },
            onLongPress: widget.selectMode ? null : () => _deletePoint(p),
            child: Icon(
              Icons.location_on,
              size: 40,
              color: isSelected ? Colors.red : Colors.blue,
            ),
          ),
        ),
      );
    }

    if (_tempPickedLatLng != null) {
      markers.add(
        Marker(
          point: _tempPickedLatLng!,
          width: 44,
          height: 44,
          child: const Icon(Icons.place, size: 40, color: Colors.deepOrange),
        ),
      );
    }

    return markers;
  }

  Future<void> _confirmSelection() async {
    // Case 1: selected an existing saved point -> return it directly
    if (_selectedSavedPoint != null) {
      Navigator.pop(context, _selectedSavedPoint);
      return;
    }

    // Case 2: picked a temp point -> ask for label, save, then return
    if (_tempPickedLatLng != null) {
      final label = await _askLabel();
      if (label == null) return;

      final now = DateTime.now().toUtc().toIso8601String();
      final point = LocationPoint(
        id: null,
        userId: widget.userId,
        lat: _tempPickedLatLng!.latitude,
        lng: _tempPickedLatLng!.longitude,
        label: label,
        createdAt: now,
      );

      final newId = await _repo.createLocation(point);
      final saved = point.copyWith(id: newId);

      Navigator.pop(context, saved);
      return;
    }

    // Nothing selected
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please pick a location on the map.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.selectMode ? 'Select Location' : 'My Locations';

    final canConfirm =
        widget.selectMode &&
        (_selectedSavedPoint != null || _tempPickedLatLng != null);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'My location',
            onPressed: _locating ? null : () => _moveToCurrentPosition(),
            icon: _locating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _zoom,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.private_memo',
                ),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
      bottomNavigationBar: widget.selectMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: canConfirm ? _confirmSelection : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Use this location'),
                ),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Tip: Tap on the map to add a new location. Long-press a marker to delete.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }
}
