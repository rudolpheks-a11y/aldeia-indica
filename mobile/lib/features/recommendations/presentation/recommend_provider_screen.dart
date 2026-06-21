import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/star_rating_bar.dart';
import '../../../shared/widgets/loading_overlay.dart';

/// Passo 2 do fluxo "Recomende um prestador": nota única em estrelas, no estilo
/// do Uber após uma corrida — uma só avaliação + comentário simples.
///
/// O backend /ratings exige 4 critérios (quality/punctuality/politeness/
/// reliability). Como aqui a experiência é de nota única, a mesma estrela é
/// aplicada aos quatro critérios.
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
        // Nota única aplicada aos quatro critérios exigidos pelo backend.
        'quality': _stars,
        'punctuality': _stars,
        'politeness': _stars,
        'reliability': _stars,
        'comment': _commentCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Obrigado pela recomendação!')),
        );
        context.pop();
      }
    } on DioException catch (e) {
      final msg = e.response?.statusCode == 409
          ? 'Você já avaliou este prestador.'
          : 'Não foi possível enviar. Tente novamente.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível enviar. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
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
        appBar: AppBar(leading: const AppBackButton(), title: const Text('Recomende um prestador')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Como foi o serviço?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Center(
                child: InteractiveStarRating(
                  value: _stars,
                  onChanged: (v) => setState(() => _stars = v),
                  size: 52,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 24,
                child: Center(
                  child: Text(
                    _stars == 0 ? '' : _labels[_stars]!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _commentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Comentário (opcional)',
                  hintText: 'Conte como foi a experiência...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: const Text('Enviar recomendação'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
