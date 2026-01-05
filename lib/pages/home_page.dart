// lib/pages/home_page.dart
import 'package:flutter/material.dart';

import '../db/app_database.dart';
import '../models/memo.dart';
import '../repositories/memo_repository.dart';
import '../widgets/memo_tile.dart';
import 'login_page.dart';
import 'memo_form_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  final int userId;
  final String username;

  const HomePage({super.key, required this.userId, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final MemoRepository _memoRepo;

  final ScrollController _scrollController = ScrollController();

  final List<Memo> _memos = [];
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  int _offset = 0;
  final int _limit = 20;

  // Search (local filter only, does not affect DB pagination)
  final TextEditingController _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _memoRepo = MemoRepository(AppDatabase.instance);
    _loadInitial();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 260) {
        _loadMore();
      }
    });

    _searchCtrl.addListener(() {
      final v = _searchCtrl.text.trim();
      if (v == _keyword) return;
      setState(() => _keyword = v);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _offset = 0;
      _memos.clear();
    });

    try {
      final firstBatch = await _memoRepo.getMemosByUserPaged(
        userId: widget.userId,
        limit: _limit,
        offset: _offset,
      );

      if (!mounted) return;
      setState(() {
        _memos.addAll(firstBatch);
        _offset += firstBatch.length;
        _hasMore = firstBatch.length == _limit;
        _isInitialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isInitialLoading = false);
      _showSnack('Failed to load: $e');
    }
  }

  Future<void> _loadMore() async {
    if (_isInitialLoading || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextBatch = await _memoRepo.getMemosByUserPaged(
        userId: widget.userId,
        limit: _limit,
        offset: _offset,
      );

      if (!mounted) return;
      setState(() {
        _memos.addAll(nextBatch);
        _offset += nextBatch.length;
        _hasMore = nextBatch.length == _limit;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      _showSnack('Failed to load more: $e');
    }
  }

  Future<void> _openAdd() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoFormPage(userId: widget.userId, memo: null),
      ),
    );

    if (changed == true) {
      await _loadInitial();
    }
  }

  Future<void> _openEdit(Memo memo) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoFormPage(userId: widget.userId, memo: memo),
      ),
    );

    if (changed == true) {
      await _loadInitial();
    }
  }

  Future<void> _deleteMemo(Memo memo) async {
    final title = memo.title.trim().isEmpty ? '(Untitled)' : memo.title.trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete memo?'),
        content: Text(
          'This will delete "$title". This action cannot be undone.',
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
      await _memoRepo.deleteMemo(memo.id!);

      if (!mounted) return;
      setState(() {
        _memos.removeWhere((m) => m.id == memo.id);
      });

      _showSnack('Deleted');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Delete failed: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _goProfile() async {
    final didLogout = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProfilePage(userId: widget.userId, username: widget.username),
      ),
    );

    // Logout
    if (didLogout == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  List<Memo> get _filteredMemos {
    if (_keyword.isEmpty) return _memos;
    final k = _keyword.toLowerCase();
    return _memos.where((m) {
      final t = m.title.toLowerCase();
      final c = (m.content ?? '').toLowerCase();
      return t.contains(k) || c.contains(k);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = _filteredMemos;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Memos'),
            Text(
              'Hi, ${widget.username}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: _goProfile,
            icon: const Icon(Icons.person_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('New Memo'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadInitial,
          child: _isInitialLoading
              ? const _LoadingSkeleton()
              : Column(
                  children: [
                    // Search bar (filters loaded items only)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 16,
                              offset: const Offset(0, 10),
                              color: Colors.black.withOpacity(0.06),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search title or content...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _keyword.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear',
                                    onPressed: () => _searchCtrl.clear(),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: _memos.isEmpty
                          ? _EmptyState(onCreate: _openAdd)
                          : (list.isEmpty
                              ? _NoSearchResult(
                                  onClear: () => _searchCtrl.clear(),
                                )
                              : _buildList(list)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildList(List<Memo> list) {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 104),
      itemCount: list.length + 1,
      itemBuilder: (context, index) {
        if (index < list.length) {
          final memo = list[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: ValueKey('memo_${memo.id}_${memo.updatedAt}'),
              direction: DismissDirection.endToStart,
              background: const _DeleteSwipeBackground(),
              confirmDismiss: (_) async {
                await _deleteMemo(memo);
                return false; // We handle deletion ourselves.
              },
              child: MemoTile(
                memo: memo,
                onTap: () => _openEdit(memo),
                onDelete: () => _deleteMemo(memo),
              ),
            ),
          );
        }

        // Footer: loading / end
        if (_isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 14),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!_hasMore) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 14),
            child: Center(
              child: Text(
                'No more items',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }

        return const SizedBox(height: 10);
      },
    );
  }
}

class _DeleteSwipeBackground extends StatelessWidget {
  const _DeleteSwipeBackground();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.delete_rounded,
        color: theme.colorScheme.onErrorContainer,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.06),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No memos yet.\nTap “New Memo” to create your first one.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Create your first memo'),
        ),
      ],
    );
  }
}

class _NoSearchResult extends StatelessWidget {
  final VoidCallback onClear;
  const _NoSearchResult({required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.06),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search_off_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No results found.\nTry a different keyword.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Clear search'),
        ),
      ],
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 220,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 12,
                          width: 140,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
