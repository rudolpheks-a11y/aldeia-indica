import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../providers_list/providers/search_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/contact_admin_button.dart';
import '../../../shared/widgets/app_scrollbar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).valueOrNull;
    final isPrestador =
        auth is AuthAuthenticated && auth.role == 'prestador';

    final unreadCount = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aldeia Indica'),
        actions: [
          IconButton(
            tooltip: unreadCount > 0
                ? 'Notificações: $unreadCount não lida${unreadCount == 1 ? '' : 's'}'
                : 'Notificações',
            icon: Badge(
              label: Text('$unreadCount'),
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () async {
              await context.push('/notifications');
              ref.invalidate(unreadNotificationsCountProvider);
            },
          ),
          IconButton(
            tooltip: 'Conversas',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/conversations'),
          ),
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
          // Excluir conta fica no overflow, não como ícone: é destrutiva e não
          // deve competir com as ações do dia a dia. "Contatar administrador"
          // veio junto pra barra não passar de 4 slots.
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (v) {
              if (v == 'admin') openAdminEmail(context);
              if (v == 'delete') _confirmDeleteAccount(context, ref);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'admin',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.email_outlined),
                  title: Text('Contatar administrador'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.delete_forever_outlined, color: AppColors.error900),
                  title: Text('Excluir conta',
                      style: TextStyle(color: AppColors.error900)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: isPrestador
            ? _PrestadorHome(
                context: context,
                providerId: auth.userId,
              )
            : _MoradorHome(context: context),
      ),
    );
  }
}

/// Exclusão de conta — dois passos de propósito: é irreversível e o usuário
/// perde o acesso na hora. O texto diz o que some (dados pessoais, perfil) e o
/// que fica (as avaliações que ele deu a outros), pra ninguém ser pego de
/// surpresa depois.
Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Excluir conta'),
      content: const Text(
        'Sua conta e seus dados pessoais serão removidos e você perderá o '
        'acesso ao aplicativo. Esta ação não pode ser desfeita.\n\n'
        'As avaliações e indicações que você deu a outras pessoas continuam '
        'valendo, mas sem o seu nome.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Excluir minha conta',
              style: TextStyle(color: AppColors.error900)),
        ),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return;

  try {
    await ref.read(authProvider.notifier).deleteAccount();
    // Sem navegação explícita: o redirect do go_router observa authProvider e
    // manda pro /login assim que o estado vira AuthUnauthenticated.
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível excluir a conta. Tente novamente.'),
          backgroundColor: AppColors.error900,
        ),
      );
    }
  }
}

class _MoradorHome extends ConsumerStatefulWidget {
  final BuildContext context;
  const _MoradorHome({required this.context});

  @override
  ConsumerState<_MoradorHome> createState() => _MoradorHomeState();
}

class _MoradorHomeState extends ConsumerState<_MoradorHome> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final context = widget.context;
    final featured = ref.watch(featuredProvidersProvider);

    return AppScrollbar(
      controller: _scrollCtrl,
      child: SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('O que você precisa hoje?',
              style: Theme.of(ctx).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('A rede de confiança do seu bairro.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            // Tiles ficam mais altos quando o usuário aumenta o texto do sistema
            // (Dynamic Type) — proporção fixa estourava com escala >1.2.
            childAspectRatio:
                1 / MediaQuery.textScalerOf(ctx).scale(1.0).clamp(1.0, 1.6),
            children: [
              _HomeTile(
                icon: Icons.search,
                label: 'Encontre um serviço',
                color: AppColors.primary,
                onTap: () => context.push('/service-picker'),
              ),
              _HomeTile(
                icon: Icons.star_rounded,
                label: 'Recomende um prestador',
                color: AppColors.secondary,
                onTap: () => context.push('/recommend'),
              ),
              _HomeTile(
                icon: Icons.campaign_rounded,
                label: 'Mural de avisos',
                color: AppColors.informational700,
                onTap: () => context.push('/bulletin'),
              ),
              _HomeTile(
                icon: Icons.qr_code_2_rounded,
                label: 'Convidar morador',
                color: AppColors.accent,
                onTap: () => _showInviteDialog(context),
              ),
              _HomeTile(
                icon: Icons.assignment_rounded,
                label: 'Meus pedidos',
                color: AppColors.secondary700,
                onTap: () => context.push('/requests'),
              ),
              _HomeTile(
                icon: Icons.favorite_rounded,
                label: 'Favoritos',
                color: AppColors.veteran900,
                onTap: () => context.push('/favorites'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          featured.when(
            data: (list) {
              if (list.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded,
                          color: AppColors.accent, size: 20),
                      const SizedBox(width: 6),
                      Text('Em destaque hoje',
                          style: Theme.of(ctx)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...list.map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              p.fullName[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(p.fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            p.categories.isNotEmpty
                                ? p.categories.take(2).join(', ')
                                : p.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: p.seals.isNotEmpty
                              ? const Icon(Icons.verified_rounded,
                                  color: AppColors.primary, size: 18)
                              : null,
                          onTap: () =>
                              context.push('/provider/${p.userId}'),
                        ),
                      )),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context) async {
    String? token;
    String? error;
    try {
      token = await ref.read(authRepositoryProvider).createInvite();
    } catch (e) {
      error = 'Não foi possível gerar o convite. Tente novamente.';
    }
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convidar morador'),
        content: error != null
            ? Text(error, style: const TextStyle(color: AppColors.error900))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compartilhe este código com quem você confia. Válido '
                    'por 72 horas. O novo morador precisa de 2 códigos, de '
                    '2 moradores diferentes, para se cadastrar.',
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    token ?? '',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                ],
              ),
        actions: [
          if (token != null)
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copiar código'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token!));
                Navigator.pop(ctx);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _PrestadorHome extends StatefulWidget {
  final BuildContext context;
  final String providerId;
  const _PrestadorHome({required this.context, required this.providerId});

  @override
  State<_PrestadorHome> createState() => _PrestadorHomeState();
}

class _PrestadorHomeState extends State<_PrestadorHome> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final context = widget.context;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gerencie seu perfil',
              style: Theme.of(ctx).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('A rede de confiança do seu bairro.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          Expanded(
            child: AppScrollbar(
              controller: _scrollCtrl,
              child: GridView.count(
              controller: _scrollCtrl,
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              // Tiles ficam mais altos quando o usuário aumenta o texto do sistema
            // (Dynamic Type) — proporção fixa estourava com escala >1.2.
            childAspectRatio:
                1 / MediaQuery.textScalerOf(ctx).scale(1.0).clamp(1.0, 1.6),
              children: [
                _HomeTile(
                  icon: Icons.checklist_rounded,
                  label: 'Cadastre suas habilidades',
                  color: AppColors.primary,
                  onTap: () => context.push('/prestador/skills'),
                ),
                _HomeTile(
                  icon: Icons.campaign_rounded,
                  label: 'Anuncie seu trabalho',
                  color: AppColors.secondary,
                  onTap: () => context.push('/prestador/anuncio'),
                ),
                _HomeTile(
                  icon: Icons.calendar_month_rounded,
                  label: 'Minha agenda',
                  color: AppColors.success,
                  onTap: () => context.push('/prestador/agenda'),
                ),
                _HomeTile(
                  icon: Icons.insights_rounded,
                  label: 'Meu painel',
                  color: AppColors.accent,
                  onTap: () => context.push('/dashboard'),
                ),
                _HomeTile(
                  icon: Icons.visibility_rounded,
                  label: 'Ver meu perfil público',
                  color: AppColors.informational700,
                  onTap: () => context.push('/provider/${widget.providerId}'),
                ),
                _HomeTile(
                  icon: Icons.assignment_rounded,
                  label: 'Pedidos abertos',
                  color: AppColors.veteran900,
                  onTap: () => context.push('/requests'),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HomeTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Fundos quentes claros (dourado, terracota) não passam 4.5:1 com branco
    // — branco sobre accent500 mede 2.11:1. Grafite sobre esses fundos passa
    // folgado (8.24:1 no dourado, 5.32:1 na terracota — mesmo padrão do
    // ScoreBadge "Bom"). Decidir pela luminância cobre qualquer cor futura.
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.light
            ? AppColors.neutral900
            : Colors.white;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: onColor, size: 40),
              Flexible(
                child: Text(
                  label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
