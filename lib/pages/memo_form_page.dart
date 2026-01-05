// lib/pages/memo_form_page.dart
//
// Create / Edit Memo page.
// Compatible with MapPage that DOES NOT define `selectMode`.
//
// This version simply opens MapPage and expects it to
// Navigator.pop(context, LocationPoint) when user confirms a location.

import 'package:flutter/material.dart';

import '../db/app_database.dart';
import '../models/memo.dart';
import '../models/location_point.dart';
import '../repositories/memo_repository.dart';
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

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  int? _locationId;
  String? _locationLabel;

  @override
  void initState() {
    super.initState();
    _memoRepo = MemoRepository(AppDatabase.instance);

    if (widget.memo != null) {
      _titleController.text = widget.memo!.title;
      _contentController.text = widget.memo!.content ?? '';
      _locationId = widget.memo!.locationId;
      _locationLabel = widget.memo!.locationLabel;
    }
  }

  String _fallbackLabel(LocationPoint p) {
    final name = (p.label ?? '').trim();
    if (name.isNotEmpty) return name;
    return 'Lat ${p.lat.toStringAsFixed(4)}, Lng ${p.lng.toStringAsFixed(4)}';
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LocationPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(
          userId: widget.userId,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _locationId = result.id;
      _locationLabel = _fallbackLabel(result);
    });
  }

  void _clearLocation() {
    setState(() {
      _locationId = null;
      _locationLabel = null;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();

    if (widget.memo == null) {
      final memo = Memo(
        id: null,
        userId: widget.userId,
        title: title,
        content: _contentController.text.trim(),
        updatedAt: now,
        locationId: _locationId,
      );
      await _memoRepo.createMemo(memo);
    } else {
      final updated = widget.memo!.copyWith(
        title: title,
        content: _contentController.text.trim(),
        updatedAt: now,
        locationId: _locationId,
        locationLabel: _locationLabel,
      );
      await _memoRepo.updateMemo(updated);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memo'),
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
                  child: Text(
                    _locationLabel == null
                        ? 'No location selected'
                        : '📍 $_locationLabel',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Location'),
                ),
                if (_locationId != null)
                  IconButton(
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
