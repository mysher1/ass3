// lib/widgets/memo_tile.dart
import 'package:flutter/material.dart';
import '../models/memo.dart';

class MemoTile extends StatelessWidget {
  final Memo memo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const MemoTile({
    super.key,
    required this.memo,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = memo.title.trim().isEmpty ? '(Untitled)' : memo.title.trim();
    final content = (memo.content ?? '').trim();
    final hasContent = content.isNotEmpty;

    final locationLabel = (memo.locationLabel ?? '').trim();
    final hasLocation = memo.locationId != null;

    return Card(
      // Let global CardThemeData do most of the work.
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarCircle(title: title),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + actions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Content preview
                    if (hasContent)
                      Text(
                        content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      )
                    else
                      Text(
                        'Tap to add details…',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                          height: 1.25,
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Meta chips (time + optional location)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TimeChip(text: _formatTime(memo.updatedAt)),
                        if (hasLocation)
                          _LocationChip(
                              text: locationLabel.isNotEmpty
                                  ? locationLabel
                                  : 'Location'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    // Keep it simple and consistent with your existing string-based timestamps.
    // If parsing fails, fall back to the raw value.
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }
}

class _AvatarCircle extends StatelessWidget {
  final String title;

  const _AvatarCircle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final letter = _firstLetter(title);
    final bg = theme.colorScheme.primaryContainer;
    final fg = theme.colorScheme.onPrimaryContainer;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: theme.textTheme.titleMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _firstLetter(String s) {
    final t = s.trim();
    if (t.isEmpty) return 'M';
    // Use the first visible character (works for letters/numbers/emoji)
    return t.characters.first.toUpperCase();
  }
}

class _TimeChip extends StatelessWidget {
  final String text;
  const _TimeChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  final String text;
  const _LocationChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.place_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
