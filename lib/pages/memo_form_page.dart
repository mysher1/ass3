// lib/pages/memo_form_page.dart
//
// Create / Edit Memo page.
// - Supports selecting a location via MapPage (which returns a LocationPoint).
// - Saves locationId into the memo.
// - Shows the location label (or a coordinate fallback).
// - If editing an existing memo that already has locationId, it loads the label from DB.

import 'package:flutter/material.dart';

import '../db/app_database.dart';
import '../models/memo.dart';
import '../models/location_point.dart';
import '../repositories/memo_repository.dart';
import '../repositories/location_repository.dart';
import 'map_page.dart';

class MemoFormPage extends StatefulWidget {
  final int userId;
  final Memo? memo;

  const MemoFormPage({
    super.key,
    required this.userId,
    this.memo,
  });

  @override
  State<MemoFormPage> createState() => _MemoFormPageState();
}

class _MemoFormPageState extends State<MemoFormPage> {
  late final MemoRepository _memoRepo;
  late final LocationRepository _locRepo;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  int? _locationId;
  String? _locationLabel;

  @override
  void initState() {
    super.initState();
    _memoRepo = MemoRepository(AppDatabase.instance);
    _locRepo = LocationRepository(AppDatabase.instance);

    if (widget.memo != null) {
      _titleController.text = widget.memo!.title;
      _contentController.text = widget.memo!.content ?? '';
      _locationId = widget.memo!.locationId;
      _locationLabel =
          widget.memo!.locationLabel; // may already be provided by JOIN
    }

    // If we have a locationId but no label yet, load it from DB for display.
    _hydrateLocationLabelIfNeeded();
  }

  Future<void> _hydrateLocationLabelIfNeeded() async {
    final id = _locationId;
    if (id == null) return;
    if ((_locationLabel ?? '').trim().isNotEmpty) return;

    try {
      final p = await _locRepo.getLocationById(id);
      if (!mounted) return;
      if (p != null) {
        setState(() => _locationLabel = p.displayLabel);
      }
    } catch (_) {
      // ignore (display will fall back below)
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LocationPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(userId: widget.userId),
      ),
    );

    if (result == null) return;

    setState(() {
      _locationId = result.id;
      _locationLabel = result.displayLabel;
    });
  }

  void _clearLocation() {
    setState(() {
      _locationId = null;
      _locationLabel = null;
    });
  }

  Future<void> _viewLocationOnMap() async {
    // For now MapPage does not accept an "initial point" parameter (to keep compatibility).
    // We simply open the map page; the user can tap the saved marker to view/use it.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(userId: widget.userId),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final content = _contentController.text.trim();

    if (widget.memo == null) {
      final memo = Memo(
        id: null,
        userId: widget.userId,
        title: title,
        content: content,
        updatedAt: now,
        locationId: _locationId,
      );
      await _memoRepo.createMemo(memo);
    } else {
      final updatedMemo = widget.memo!.copyWith(
        title: title,
        content: content,
        updatedAt: now,
        locationId: _locationId,
        // Keep label so UI can show immediately; DB is still source of truth via JOIN later.
        locationLabel: _locationLabel,
      );
      await _memoRepo.updateMemo(updatedMemo);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.memo != null;

    final shownLabel = (_locationLabel ?? '').trim();
    final hasLocation = _locationId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Memo' : 'New Memo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: hasLocation ? _viewLocationOnMap : null,
                    child: Text(
                      hasLocation
                          ? '📍 ${shownLabel.isNotEmpty ? shownLabel : 'Selected location'}'
                          : 'No location selected',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        decoration: hasLocation
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Location'),
                ),
                const SizedBox(width: 8),
                if (hasLocation)
                  IconButton(
                    tooltip: 'Clear location',
                    onPressed: _clearLocation,
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
