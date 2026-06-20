import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Painel Admin'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Usuários'),
            Tab(text: 'Documentos'),
            Tab(text: 'Comunidades'),
          ]),
        ),
        body: const TabBarView(children: [
          _UsersTab(),
          _DocumentsTab(),
          _CommunitiesTab(),
        ]),
      ),
    );
  }
}

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(_usersProvider);
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (list) => ListView.builder(
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
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => Colors.green,
      'pending' => Colors.orange,
      'suspended' => Colors.red,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }
}

class _DocumentsTab extends ConsumerWidget {
  const _DocumentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(_documentsProvider);
    return docs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (list) => list.isEmpty
          ? const Center(child: Text('Nenhum documento pendente'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final d = list[i];
                return Card(
                  child: ListTile(
                    title: Text(d['full_name'] as String),
                    subtitle: Text(d['email'] as String),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _review(context, ref, d['user_id'] as String, true),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _review(context, ref, d['user_id'] as String, false),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _review(BuildContext context, WidgetRef ref, String userId, bool approve) async {
    try {
      await ref.read(apiClientProvider).post(
        '/admin/documents/$userId/review',
        data: {'approve': approve},
      );
      ref.invalidate(_documentsProvider);
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
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
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
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final communities = ref.watch(_communitiesProvider);
    return SingleChildScrollView(
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
    );
  }
}

final _usersProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/admin/users');
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});

final _documentsProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/admin/documents');
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});

final _communitiesProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiEndpoints.communities);
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});
