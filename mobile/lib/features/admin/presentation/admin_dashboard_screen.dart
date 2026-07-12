import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bulletin/providers/bulletin_provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scrollbar.dart';
import '../../../shared/widgets/app_error_view.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
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
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Visão Geral'),
            Tab(text: 'Usuários'),
            Tab(text: 'Desativados'),
            Tab(text: 'Mural'),
            Tab(text: 'Comunidades'),
          ]),
        ),
        body: const TabBarView(children: [
          _OverviewTab(),
          _UsersTab(),
          _DeletedTab(),
          _BulletinTab(),
          _CommunitiesTab(),
        ]),
      ),
    );
  }
}

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  final _gridCtrl = ScrollController();

  @override
  void dispose() {
    _gridCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(_statsProvider);
    return stats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: AppErrorView(onRetry: () => ref.invalidate(_statsProvider))),
      data: (s) => RefreshIndicator(
        onRefresh: () => ref.refresh(_statsProvider.future),
        child: AppScrollbar(
          controller: _gridCtrl,
          child: GridView.count(
          controller: _gridCtrl,
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _StatTile(
              icon: Icons.home_outlined,
              label: 'Moradores',
              value: '${s['moradores_ativos']}',
              sublabel: '${s['total_moradores']} no total',
              onTap: () => _showDetailSheet(
                context,
                title: 'Moradores',
                endpoint: '/admin/users?role=morador',
                itemBuilder: (u) => ListTile(
                  title: Text(u['full_name'] as String),
                  subtitle: Text(u['email'] as String),
                  trailing: _StatusChip(status: u['status'] as String),
                ),
              ),
            ),
            _StatTile(
              icon: Icons.engineering_outlined,
              label: 'Prestadores',
              value: '${s['prestadores_ativos']}',
              sublabel: '${s['total_prestadores']} no total',
              onTap: () => _showDetailSheet(
                context,
                title: 'Prestadores',
                endpoint: '/admin/users?role=prestador',
                itemBuilder: (u) => ListTile(
                  title: Text(u['full_name'] as String),
                  subtitle: Text(u['email'] as String),
                  trailing: _StatusChip(status: u['status'] as String),
                ),
              ),
            ),
            _StatTile(
              icon: Icons.category_outlined,
              label: 'Categorias de serviço',
              value: '${s['total_categorias']}',
              onTap: () => _showDetailSheet(
                context,
                title: 'Categorias de serviço',
                endpoint: '/categories',
                itemBuilder: (c) => ListTile(
                  title: Text(c['name_pt'] as String),
                  trailing: Text('${c['provider_count']} prestador(es)'),
                ),
              ),
            ),
            _StatTile(
              icon: Icons.handyman_outlined,
              label: 'Serviços oferecidos',
              value: '${s['total_servicos_oferecidos']}',
              onTap: () => _showDetailSheet(
                context,
                title: 'Serviços oferecidos',
                endpoint: '/admin/provider-services',
                itemBuilder: (item) => ListTile(
                  title: Text(item['provider_name'] as String),
                  subtitle: Text(item['category_name'] as String),
                ),
              ),
            ),
            _StatTile(
              icon: Icons.assignment_outlined,
              label: 'Pedidos de serviço',
              value: '${s['total_pedidos']}',
              onTap: () => _showDetailSheet(
                context,
                title: 'Pedidos de serviço',
                endpoint: '/requests?status=all',
                itemBuilder: (item) => ListTile(
                  title: Text(item['title'] as String? ?? ''),
                  subtitle: Text(
                      '${item['requester'] ?? ''} · ${item['category'] ?? 'Geral'} · ${item['status']}'),
                ),
              ),
            ),
            _StatTile(
              icon: Icons.star_outline,
              label: 'Avaliações',
              value: '${s['total_avaliacoes']}',
              onTap: () => _showDetailSheet(
                context,
                title: 'Avaliações',
                endpoint: '/admin/ratings',
                itemBuilder: (item) => ListTile(
                  title: Text(
                      '${item['rater_name']} → ${item['provider_name']}'),
                  subtitle: Text(item['comment'] as String? ?? 'Sem comentário'),
                  trailing: Text(
                      (item['average'] as num).toStringAsFixed(1)),
                ),
              ),
            ),
            _StatTile(
              icon: Icons.thumb_up_outlined,
              label: 'Recomendações',
              value: '${s['total_recomendacoes']}',
              onTap: () => _showDetailSheet(
                context,
                title: 'Recomendações',
                endpoint: '/admin/recommendations',
                itemBuilder: (item) => ListTile(
                  title: Text(
                      '${item['recommender_name']} → ${item['provider_name']}'),
                ),
              ),
            ),
            _StatTile(
              icon: Icons.campaign_outlined,
              label: 'Avisos pendentes',
              value: '${s['avisos_pendentes']}',
              onTap: () => DefaultTabController.of(context).animateTo(2),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sublabel;
  final VoidCallback? onTap;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.sublabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary700, size: 26),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              if (sublabel != null)
                Text(sublabel!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Provider genérico pra qualquer lista de detalhe do admin — cada card da
/// Visão Geral aponta pro endpoint que já tem o dado, sem precisar de um
/// provider dedicado por categoria.
final _adminListProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, endpoint) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(endpoint);
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});

void _showDetailSheet(
  BuildContext context, {
  required String title,
  required String endpoint,
  required Widget Function(Map<String, dynamic> item) itemBuilder,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final async = ref.watch(_adminListProvider(endpoint));
                return async.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(child: AppErrorView(onRetry: () => ref.invalidate(_adminListProvider(endpoint)))),
                  data: (list) => list.isEmpty
                      ? const Center(child: Text('Nada encontrado'))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) => itemBuilder(list[i]),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _listCtrl = ScrollController();

  /// Formata o registro do aceite de avaliações públicas do prestador.
  static String _acknowledgmentLabel(String? isoTimestamp) {
    if (isoTimestamp == null) {
      return 'Sem aceite registrado (cadastro anterior a 12/07/2026)';
    }
    final dt = DateTime.parse(isoTimestamp).toLocal();
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return 'Aceite de avaliações: $dd/$mm/${dt.year} às $hh:$min';
  }

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
      error: (_, __) => Center(child: AppErrorView(onRetry: () => ref.invalidate(_usersProvider))),
      data: (list) => AppScrollbar(
        controller: _listCtrl,
        child: ListView.builder(
        controller: _listCtrl,
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final u = list[i];
          final isPending = u['status'] == 'pending';
          return Card(
            child: ListTile(
              title: Text(u['full_name'] as String),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${u['role']} · ${u['email']}'),
                  // Registro do aceite de avaliações públicas — só faz
                  // sentido para prestadores. NULL = cadastro anterior à
                  // exigência (2026-07-12), não é irregularidade.
                  if (u['role'] == 'prestador')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _acknowledgmentLabel(
                            u['ratings_acknowledged_at'] as String?),
                        style: TextStyle(
                          fontSize: 12,
                          color: u['ratings_acknowledged_at'] != null
                              ? AppColors.primary700
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusChip(status: u['status'] as String),
                  if (isPending) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip:
                          'Aprovar manualmente (backup — sem os 2 códigos de convite)',
                      icon: const Icon(Icons.check_circle_outline,
                          color: AppColors.primary700),
                      onPressed: () =>
                          _approve(context, u['id'] as String),
                    ),
                  ],
                  // Admin não se desativa nem desativa outro admin — o backend
                  // bloqueia com 403; aqui o botão nem aparece.
                  if (u['role'] != 'admin')
                    IconButton(
                      tooltip: 'Desativar usuário',
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.error900),
                      onPressed: () => _delete(
                        context,
                        u['id'] as String,
                        u['full_name'] as String,
                      ),
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

  Future<void> _delete(
      BuildContext context, String userId, String fullName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desativar usuário'),
        content: Text(
          'Desativar a conta de $fullName? O perfil sai do ar e a pessoa perde o '
          'acesso ao aplicativo.\n\n'
          'Os dados e o histórico ficam guardados, e o e-mail continua vinculado '
          'a esta conta — ela não consegue se cadastrar de novo com ele. Só você '
          'pode reverter esta desativação.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desativar',
                style: TextStyle(color: AppColors.error900)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(apiClientProvider).delete(ApiEndpoints.adminUser(userId));
      ref.invalidate(_usersProvider);
      // A Visão Geral conta usuários e a aba Desativados ganha o registro novo —
      // sem invalidar, ambas seguem com os dados antigos.
      ref.invalidate(_statsProvider);
      ref.invalidate(_deletedUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fullName foi desativado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível desativar o usuário. Tente novamente.'),
            backgroundColor: AppColors.error900,
          ),
        );
      }
    }
  }

  Future<void> _approve(BuildContext context, String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprovar morador'),
        content: const Text(
            'Esse morador não teve os 2 códigos de convite. Ativar mesmo '
            'assim, sem a indicação de outros moradores?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(apiClientProvider).put(
        '/admin/users/$userId/status',
        data: {'status': 'active'},
      );
      ref.invalidate(_usersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível atualizar o usuário. Tente novamente.')),
        );
      }
    }
  }
}

class _DeletedTab extends ConsumerStatefulWidget {
  const _DeletedTab();

  @override
  ConsumerState<_DeletedTab> createState() => _DeletedTabState();
}

class _DeletedTabState extends ConsumerState<_DeletedTab> {
  final _listCtrl = ScrollController();

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  static String _fmt(String? iso) {
    if (iso == null) return 'data desconhecida';
    final dt = DateTime.parse(iso).toLocal();
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} às $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(_deletedUsersProvider);
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
          child: AppErrorView(onRetry: () => ref.invalidate(_deletedUsersProvider))),
      data: (list) => list.isEmpty
          ? const Center(child: Text('Nenhuma conta desativada'))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppColors.secondary50,
                  child: const Text(
                    'O e-mail continua vinculado a estas contas: ninguém consegue '
                    'se recadastrar com ele. Quem se desativou sozinho pode voltar '
                    'reativando a conta — com o histórico de avaliações junto. Quem '
                    'foi desativado por você, não.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: AppScrollbar(
                    controller: _listCtrl,
                    child: ListView.builder(
                      controller: _listCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final u = list[i];
                        final byAdmin = u['deleted_by_admin'] == true;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              byAdmin ? Icons.gavel_rounded : Icons.person_off_outlined,
                              color: byAdmin ? AppColors.error900 : AppColors.textSecondary,
                            ),
                            title: Text(u['full_name'] as String),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${u['role']} · ${u['email']}'),
                                Text(
                                  'Desativada em ${_fmt(u['deleted_at'] as String?)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            trailing: Chip(
                              label: Text(
                                byAdmin ? 'pelo admin' : 'pelo usuário',
                                style: const TextStyle(fontSize: 11, color: Colors.white),
                              ),
                              backgroundColor:
                                  byAdmin ? AppColors.error900 : AppColors.neutral500,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
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
      label: Text(status, style: const TextStyle(fontSize: 12, color: Colors.white)),
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
      error: (_, __) => Center(child: AppErrorView(onRetry: () => ref.invalidate(bulletinPendingProvider))),
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
                              // O tema global define minimumSize com largura
                              // infinita (botões full-width em forms). Dentro de
                              // um Row isso vira constraint inválida (Row dá
                              // largura ilimitada) e quebra o layout da lista
                              // inteira — daí a aba ficava em branco. Aqui o
                              // botão precisa dimensionar pelo conteúdo.
                              style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 40)),
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
          const SnackBar(content: Text('Não foi possível revisar o aviso. Tente novamente.')),
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
          const SnackBar(content: Text('Não foi possível criar a comunidade. Tente novamente.'), backgroundColor: AppColors.error900),
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
            error: (_, __) => AppErrorView(compact: true, onRetry: () => ref.invalidate(_communitiesProvider)),
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

final _statsProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/admin/stats');
  return resp.data as Map<String, dynamic>;
});

/// Contas desativadas — trilha antifraude. Um prestador pode desativar a conta
/// pra tentar escapar de uma avaliação ruim; o admin precisa enxergar isso, e o
/// e-mail continua preso à conta (recadastro com ele é bloqueado).
final _deletedUsersProvider = FutureProvider((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/admin/users?deleted=true');
  return (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
});

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
