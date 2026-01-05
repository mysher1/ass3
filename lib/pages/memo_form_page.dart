// lib/pages/memo_form_page.dart
import 'package:flutter/material.dart';

import '../models/memo.dart';
import '../repositories/memo_repository.dart';

class MemoFormPage extends StatefulWidget {
  final int userId;
  final Memo? memo; // null = create; non-null = edit

  const MemoFormPage({super.key, required this.userId, required this.memo});

  @override
  State<MemoFormPage> createState() => _MemoFormPageState();
}

class _MemoFormPageState extends State<MemoFormPage> {
  final _repo = MemoRepository();

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  bool _saving = false;
  bool _dirty = false;

  bool get _isEdit => widget.memo != null;

  @override
  void initState() {
    super.initState();

    if (_isEdit) {
      _titleCtrl.text = widget.memo!.title;
      _contentCtrl.text = widget.memo!.content ?? '';
      _dirty = false;
    }

    _titleCtrl.addListener(_markDirty);
    _contentCtrl.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_dirty) return true;

    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved edits. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return leave == true;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_saving) return;
    setState(() => _saving = true);

    final title = _titleCtrl.text.trim();
    final rawContent = _contentCtrl.text.trim();
    final String? content = rawContent.isEmpty ? null : rawContent;

    try {
      if (_isEdit) {
        final memoId = widget.memo!.id;
        if (memoId == null) throw Exception('Memo id is null');

        await _repo.updateMemo(
          memoId: memoId,
          userId: widget.userId,
          title: title,
          content: content,
        );
      } else {
        await _repo.createMemo(
          userId: widget.userId,
          title: title,
          content: content,
        );
      }

      if (!mounted) return;

      _dirty = false;
      Navigator.pop(context, true); // tell previous page to refresh
    } catch (e) {
      if (!mounted) return;
      _showSnack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = _isEdit ? 'Edit Memo' : 'New Memo';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final leave = await _confirmLeaveIfDirty();
        if (leave && mounted) Navigator.pop(context, false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(headline),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              final leave = await _confirmLeaveIfDirty();
              if (leave && mounted) Navigator.pop(context, false);
            },
          ),
        ),

        // Light blue gradient background
        body: Stack(
          children: [
            // Background gradient (purple -> light blue)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.06),
                    Colors.blue.shade100.withOpacity(0.20),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InfoBanner(isEdit: _isEdit),
                        const SizedBox(height: 14),

                        // Form Card
                        Card(
                          elevation: 0.8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _titleCtrl,
                                    textInputAction: TextInputAction.next,
                                    maxLength: 40,
                                    decoration: InputDecoration(
                                      labelText: 'Title',
                                      hintText:
                                          'e.g. Grocery list, Meeting notes',
                                      prefixIcon: const Icon(
                                        Icons.title_rounded,
                                      ),
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withOpacity(0.45),
                                    ),
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) return 'Title is required';
                                      if (s.length > 40) {
                                        return 'Title must be ≤ 40 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  TextFormField(
                                    controller: _contentCtrl,
                                    textInputAction: TextInputAction.newline,
                                    minLines: 7,
                                    maxLines: 14,
                                    decoration: InputDecoration(
                                      labelText: 'Content (optional)',
                                      hintText:
                                          'Write anything you want to remember…',
                                      alignLabelWithHint: true,
                                      prefixIcon: const Padding(
                                        padding: EdgeInsets.only(bottom: 140),
                                        child: Icon(Icons.notes_rounded),
                                      ),
                                      border: const OutlineInputBorder(),
                                      filled: true,
                                      fillColor: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withOpacity(0.35),
                                    ),
                                  ),

                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 18,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _isEdit
                                              ? 'Last updated: ${_formatTime(widget.memo?.updatedAt)}'
                                              : 'Will be saved with the current time',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                      if (_dirty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.10),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            'Unsaved',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom “Save” bar
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withOpacity(0.22),
                            ),
                          ),
                        ),
                        child: SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              _saving
                                  ? 'Saving…'
                                  : (_isEdit ? 'Save changes' : 'Create memo'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }
}

class _InfoBanner extends StatelessWidget {
  final bool isEdit;
  const _InfoBanner({required this.isEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.74),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isEdit ? Icons.edit_note_rounded : Icons.note_add_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Editing' : 'Creating',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEdit
                      ? 'Update the title or content, then use the bottom button to save.'
                      : 'Enter a title and optionally content, then create your memo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
