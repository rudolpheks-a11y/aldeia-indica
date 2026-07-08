import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Estado de erro padrão para carregamentos que falharam.
///
/// Sempre usar este widget no `error:` de um `AsyncValue.when` em vez de
/// interpolar a exceção (`Text('Erro: $e')`) — a exceção crua do Dio expõe
/// detalhes técnicos (status code, URL, stack) que não ajudam o usuário e
/// já chegaram a ocupar a tela inteira em produção.
class AppErrorView extends StatelessWidget {
  final String message;

  /// Reconsulta os dados — normalmente `() => ref.invalidate(provider)`.
  final VoidCallback? onRetry;

  /// Versão reduzida para uso embutido em seções (sem ícone grande).
  final bool compact;

  const AppErrorView({
    super.key,
    this.message = 'Não foi possível carregar. Tente novamente.',
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            const Icon(Icons.cloud_off_outlined,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tentar de novo'),
            ),
          ],
        ],
      ),
    );
  }
}
