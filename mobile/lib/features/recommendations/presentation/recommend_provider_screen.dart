import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../auth/providers/auth_provider.dart';
import '../../provider_profile/providers/profile_provider.dart';

class RecommendProviderScreen extends ConsumerStatefulWidget {
  final String providerId;
  const RecommendProviderScreen({super.key, required this.providerId});

  @override
  ConsumerState<RecommendProviderScreen> createState() =>
      _RecommendProviderScreenState();
}

class _RecommendProviderScreenState
    extends ConsumerState<RecommendProviderScreen> {
  int _stars = 0;
  final _commentCtrl = TextEditingController();
  bool _isLoading = false;

  static const _labels = {
    1: 'Ruim',
    2: 'Regular',
    3: 'Bom',
    4: 'Muito bom',
    5: 'Excelente',
  };

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toque nas estrelas para dar uma nota')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(apiClientProvider).post(ApiEndpoints.ratings, data: {
        'provider_id': widget.providerId,
        'quality': _stars,
        'punctuality': _stars,
        'politeness': _stars,
        'reliability': _stars,
        'comment': _commentCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Obrigado pela avaliação!')),
        );
        context.pop();
      }
    } on DioException catch (e) {
      final msg = e.response?.statusCode == 409
          ? 'Você já avaliou este prestador.'
          : 'Não foi possível enviar. Tente novamente.';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível enviar. Tente novamente.'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(providerProfileProvider(widget.providerId));

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Avaliar prestador'),
        ),
        body: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _buildBody(context, null, []),
          data: (profile) {
            final name = profile['full_name'] as String? ?? '';
            final cats = (profile['categories'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                [];
            return _buildBody(context, name, cats);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, String? name, List<String> cats) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ── cabeçalho com avatar + nome ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    name != null && name.isNotEmpty
                        ? name
                            .split(' ')
                            .take(2)
                            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
                            .join()
                        : '?',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  name ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (cats.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    cats.join(' · '),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          // ── estrelas ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
            child: Column(
              children: [
                const Text(
                  'Como foi o serviço?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                _StarRow(
                  value: _stars,
                  onChanged: (v) => setState(() => _stars = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 22,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _stars == 0
                        ? const SizedBox.shrink()
                        : Text(
                            _labels[_stars]!,
                            key: ValueKey(_stars),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // ── comentário ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Deixe um comentário (opcional)...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── botão ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Enviar avaliação',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StarRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 52,
              color: filled ? AppColors.accent : Colors.grey[300],
            ),
          ),
        );
      }),
    );
  }
}
