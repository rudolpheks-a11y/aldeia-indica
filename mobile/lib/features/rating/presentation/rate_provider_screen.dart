import 'package:flutter/material.dart';
import '../../../shared/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../provider_profile/providers/profile_provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../shared/widgets/star_rating_bar.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/app_scrollbar.dart';
import '../../../core/constants/app_colors.dart';

class RateProviderScreen extends ConsumerStatefulWidget {
  final String providerId;

  const RateProviderScreen({super.key, required this.providerId});

  @override
  ConsumerState<RateProviderScreen> createState() => _RateProviderScreenState();
}

class _RateProviderScreenState extends ConsumerState<RateProviderScreen> {
  int _quality = 0;
  int _punctuality = 0;
  int _politeness = 0;
  int _reliability = 0;
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_quality == 0 || _punctuality == 0 || _politeness == 0 || _reliability == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avalie todos os critérios')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(apiClientProvider).post(ApiEndpoints.ratings, data: {
        'provider_id': widget.providerId,
        'quality': _quality,
        'punctuality': _punctuality,
        'politeness': _politeness,
        'reliability': _reliability,
        'comment': _commentCtrl.text.trim(),
      });
      invalidateProviderData(ref, widget.providerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avaliação enviada!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar a avaliação. Tente novamente.'), backgroundColor: AppColors.error900),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(leading: const AppBackButton(), title: const Text('Avaliar Prestador')),
        body: AppScrollbar(
          controller: _scrollCtrl,
          child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CriterionRow(
                  label: 'Qualidade do serviço',
                  value: _quality,
                  onChanged: (v) => setState(() => _quality = v)),
              const SizedBox(height: 16),
              _CriterionRow(
                  label: 'Pontualidade',
                  value: _punctuality,
                  onChanged: (v) => setState(() => _punctuality = v)),
              const SizedBox(height: 16),
              _CriterionRow(
                  label: 'Educação',
                  value: _politeness,
                  onChanged: (v) => setState(() => _politeness = v)),
              const SizedBox(height: 16),
              _CriterionRow(
                  label: 'Confiabilidade',
                  value: _reliability,
                  onChanged: (v) => setState(() => _reliability = v)),
              const SizedBox(height: 24),
              TextField(
                controller: _commentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Comentário (opcional)',
                  hintText: 'Conte sua experiência...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: const Text('Enviar Avaliação'),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _CriterionRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 15)),
        ),
        InteractiveStarRating(value: value, onChanged: onChanged, size: 32),
      ],
    );
  }
}
