import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/star_rating_bar.dart';
import '../../../shared/widgets/score_badge.dart';
import '../../../shared/widgets/app_scrollbar.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String providerId;
  const ProfileScreen({super.key, required this.providerId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerId = widget.providerId;
    final profile = ref.watch(providerProfileProvider(providerId));
    final auth = ref.watch(authProvider).valueOrNull;
    final isSelf =
        auth is AuthAuthenticated && auth.userId == providerId;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Perfil do Prestador'),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (p) => AppScrollbar(
          controller: _scrollCtrl,
          child: SingleChildScrollView(
          controller: _scrollCtrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(p: p),
              _Seals(p: p),
              const Divider(),
              _InfoSection(p: p),
              const Divider(),
              _Categories(p: p),
              const Divider(),
              _Availability(p: p),
              const Divider(),
              _RecommendedBy(providerId: providerId),
              const Divider(),
              if (!isSelf) _Reviews(providerId: providerId),
              const SizedBox(height: 80),
            ],
          ),
        ),
        ),
      ),
      bottomNavigationBar: _BottomActions(providerId: providerId),
    );
  }
}

class _Header extends StatelessWidget {
  final Map<String, dynamic> p;
  const _Header({required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey[200],
            child: Text(
              (p['full_name'] as String)[0].toUpperCase(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['full_name'] as String,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (p['avg_rating'] != null)
                  Row(children: [
                    StarRatingBar(
                        rating: (p['avg_rating'] as num).toDouble()),
                    const SizedBox(width: 4),
                    Text((p['avg_rating'] as num).toStringAsFixed(1),
                        style: const TextStyle(fontSize: 14)),
                  ]),
              ],
            ),
          ),
          ScoreBadge(score: (p['score_aldeia'] as num).toDouble()),
        ],
      ),
    );
  }
}

class _Seals extends StatelessWidget {
  final Map<String, dynamic> p;
  const _Seals({required this.p});

  static const _sealLabel = {
    'bem_avaliado': ('Bem avaliado', Icons.star_rounded, AppColors.sealBemAvaliado),
    'muito_indicado': ('Muito indicado', Icons.thumb_up_rounded, AppColors.sealMuitoIndicado),
    'veterano': ('Veterano', Icons.military_tech_rounded, AppColors.sealVeterano),
    'completo': ('Perfil completo', Icons.verified_rounded, AppColors.sealCompleto),
  };

  @override
  Widget build(BuildContext context) {
    final seals = (p['seals'] as List<dynamic>?)?.cast<String>() ?? [];
    if (seals.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: seals.map((s) {
          final meta = _sealLabel[s];
          if (meta == null) return const SizedBox.shrink();
          final (label, icon, color) = meta;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final Map<String, dynamic> p;
  const _InfoSection({required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _InfoRow(Icons.location_city, p['city'] as String),
          _InfoRow(Icons.home_work,
              '${p['years_in_neighborhood']} anos atuando no bairro'),
          if (p['professional_bio'] != null)
            _InfoRow(Icons.info_outline, p['professional_bio'] as String),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  final Map<String, dynamic> p;
  const _Categories({required this.p});

  @override
  Widget build(BuildContext context) {
    final cats = (p['categories'] as List<dynamic>?)?.cast<String>() ?? [];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Serviços',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: cats
                .map((c) => Chip(
                      label: Text(c),
                      backgroundColor: AppColors.primary50,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Availability extends StatelessWidget {
  final Map<String, dynamic> p;
  const _Availability({required this.p});

  static const _dayNames = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  @override
  Widget build(BuildContext context) {
    final slots = (p['availability'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    if (slots.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Disponibilidade',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((sl) {
              final day = _dayNames[sl['day_of_week'] as int];
              final start = (sl['start_time'] as String).substring(0, 5);
              final end = (sl['end_time'] as String).substring(0, 5);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(day,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.primary700)),
                    const SizedBox(width: 6),
                    Text('$start–$end',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RecommendedBy extends ConsumerWidget {
  final String providerId;
  const _RecommendedBy({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(recommendationCountProvider(providerId));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: countAsync.when(
        data: (count) => count == 0
            ? const SizedBox.shrink()
            : Row(
                children: [
                  const Icon(Icons.thumb_up_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Recomendado por $count ${count == 1 ? 'morador' : 'moradores'}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _Reviews extends ConsumerWidget {
  final String providerId;
  const _Reviews({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratings = ref.watch(ratingsProvider(providerId));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Avaliações',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ratings.when(
            data: (list) => list.isEmpty
                ? const Text('Sem avaliações ainda',
                    style: TextStyle(color: Colors.grey))
                : Column(
                    children: list.take(3).map((r) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(r['rater_name'] as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const Spacer(),
                                StarRatingBar(
                                    rating:
                                        (r['overall'] as num).toDouble(),
                                    size: 14),
                              ]),
                              if (r['comment'] != null) ...[
                                const SizedBox(height: 4),
                                Text(r['comment'] as String,
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends ConsumerStatefulWidget {
  final String providerId;
  const _BottomActions({required this.providerId});

  @override
  ConsumerState<_BottomActions> createState() => _BottomActionsState();
}

class _BottomActionsState extends ConsumerState<_BottomActions> {
  bool _loading = false;

  Future<void> _startChat() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.post('/chat/conversations',
          data: {'other_user_id': widget.providerId});
      final convId = resp.data['id'] as String;
      if (mounted) context.push('/chat/$convId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar conversa: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).valueOrNull;
    final isSelf =
        auth is AuthAuthenticated && auth.userId == widget.providerId;
    if (isSelf) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.star_rate),
                label: const Text('Avaliar'),
                onPressed: () => context.push('/rate/${widget.providerId}'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.chat_bubble_outline),
                label: const Text('Contatar'),
                onPressed: _loading ? null : _startChat,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
