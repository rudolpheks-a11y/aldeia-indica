import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/star_rating_bar.dart';
import '../../../shared/widgets/score_badge.dart';

class ProfileScreen extends ConsumerWidget {
  final String providerId;

  const ProfileScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(providerProfileProvider(providerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil do Prestador')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (p) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(p: p),
              const Divider(),
              _InfoSection(p: p),
              const Divider(),
              _Categories(p: p),
              const Divider(),
              _Photos(p: p),
              const Divider(),
              _RecommendedBy(providerId: providerId),
              const Divider(),
              _Reviews(providerId: providerId),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomActions(providerId: providerId),
    );
  }
}

class _Header extends StatelessWidget {
  final dynamic p;
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
                    Text(
                        (p['avg_rating'] as num).toStringAsFixed(1),
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

class _InfoSection extends StatelessWidget {
  final dynamic p;
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
  final dynamic p;
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
                      backgroundColor: Colors.green[50],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Photos extends StatelessWidget {
  final dynamic p;
  const _Photos({required this.p});

  @override
  Widget build(BuildContext context) {
    final photos =
        (p['photos'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    if (photos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Trabalhos realizados',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: photos.length,
            itemBuilder: (_, i) => Container(
              width: 120,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendedBy extends ConsumerWidget {
  final String providerId;
  const _RecommendedBy({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref.watch(recommendationsProvider(providerId));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Indicado por',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          recs.when(
            data: (list) => list.isEmpty
                ? const Text('Sem indicações ainda',
                    style: TextStyle(color: Colors.grey))
                : Column(
                    children: list
                        .take(3)
                        .map((r) => Text(
                              '✓ ${r['full_name']}',
                              style: const TextStyle(fontSize: 14),
                            ))
                        .toList(),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
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
                                    rating: (r['overall'] as num).toDouble(),
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
      final resp = await api.post('/chat/conversations', data: {
        'other_user_id': widget.providerId,
      });
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
