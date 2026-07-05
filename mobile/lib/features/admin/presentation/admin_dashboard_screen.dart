import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bulletin/providers/bulletin_provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scrollbar.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Painel Admin'),
          actions: [
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sair da conta'),
                    content: const Text('Tem certeza que deseja sair?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sair',
                            style: TextStyle(color: AppColors.error900)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(authProvider.notifier).logout();
                }
              },
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Usuários'),
            Tab(text: 'Mural'),
            Tab(text: 'Comunidades'),
          ]),
        ),
        body: const TabBarView(children: [
          _UsersTab(),
          _BulletinTab(),
          _CommunitiesTab(),
        ]),
      ),
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _listCtrl = ScrollController();

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(_usersProvider);
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (list) => AppScrollbar(
        controller: _listCtrl,
        child: ListView.builder(
        controller: _listCtrl,
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final u = list[i];
          return Card(
            child: ListTile(
              title: Text(u['full_name'] as String),
              subtitle: Text('${u['role']} · ${u['email']}'),
              trailing: _StatusChip(status: u['status'] as String),
            ),
          );
        },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      // 'pending' usa secondary-700, não secondary-500: branco sobre
      // secondary-500 falha 4.5:1 (ver DESIGN_1.md).
      'active' => AppColors.primary700,
      'pending' => AppColors.secondary700,
      'suspended' => AppColors.error900,
      _ => AppColors.neutral500,
    };
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }
}

class _BulletinTab extends ConsumerStatefulWidget {
  const _BulletinTab();

  @override
  ConsumerState<_BulletinTab> createState() => _BulletinTabState();
}

class _BulletinTabState extends ConsumerState<_BulletinTab> {
  final _listCtrl = ScrollController();

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(bulletinPendingProvider);
    return pending.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (list) => list.isEmpty
          ? const Center(child: Text('Nenhum aviso pendente'))
          : AppScrollbar(
              controller: _listCtrl,
              child: ListView.builder(
              controller: _listCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final p = list[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['author_name'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(p['content'] as String,
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.close,
                                  color: AppColors.error900, size: 16),
                              label: const Text('Rejeitar',
                                  style: TextStyle(color: AppColors.error900)),
                              onPressed: () => _review(
                                  context, ref, p['id'] as String,
                                  approve: false),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Aprovar'),
                              onPressed: () => _review(
                                  context, ref, p['id'] as String,
                                  approve: true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              ),
            ),
    );
  }

  Future<void> _review(BuildContext context, WidgetRef ref, String id,
      {required bool approve}) async {
    try {
      await ref
          .read(bulletinRepoProvider)
          .review(id, approve: approve);
      ref.invalidate(bulletinPendingProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }
}

class _CommunitiesTab extends ConsumerStatefulWidget {
  const _CommunitiesTab();

  @override
  ConsumerState<_CommunitiesTab> createState() => _CommunitiesTabState();
}

class _CommunitiesTabState extends ConsumerState<_CommunitiesTab> {
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.isEmpty || _slugCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).post(
        '/admin/communities',
        data: {
          'name': _nameCtrl.text.trim(),
          'slug': _slugCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'state': _stateCtrl.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comunidade criada!')),
        );
        _nameCtrl.clear();
        _slugCtrl.clear();
        _cityCtrl.clear();
        _stateCtrl.clear();
        ref.invalidate(_communitiesProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error900),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final communities = ref.watch(_communitiesProvider);
    return AppScrollbar(
      controller: _scrollCtrl,
      child: SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Nova Comunidade',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome')),
                  const SizedBox(height: 8),
                  TextField(controller: _slugCtrl, decoration: const InputDecoration(labelText: 'Slug (ex: aldeia-da-serra)')),
                  const SizedBox(height: 8),
                  TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'Cidade')),
                  const SizedBox(height: 8),
                  TextField(controller: _stateCtrl, decoration: const InputDecoration(labelText: 'Estado (ex: SP)')),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loading ? null : _create,
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Criar Comunidade'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Comunidades ativas',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          communities.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Erro: $e'),
            data: (list) => Column(
              children: list.map((c) => ListTile(
                title: Text(c['name'] as String),
                subtitle: Text('${c['city']} · ${c['slug']}'),
              )).toList(),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

final _usersProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/admin/users');
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});

final _communitiesProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.communities);
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});
