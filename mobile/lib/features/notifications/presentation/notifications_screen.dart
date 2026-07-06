import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_scrollbar.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Abrir a tela já limpa o badge — best-effort, não bloqueia a leitura
    // da lista se falhar.
    ref.read(apiClientProvider).post(ApiEndpoints.notificationsReadAll).then(
          (_) => ref.invalidate(unreadNotificationsCountProvider),
        );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTap(Map<String, dynamic> n) {
    final type = n['type'] as String?;
    final relatedId = n['related_id'] as String?;
    switch (type) {
      case 'request_response':
        if (relatedId != null) context.push('/requests/$relatedId');
        break;
      case 'rating_received':
      case 'recommendation_received':
        context.push('/dashboard');
        break;
      case 'question_received':
        final auth = ref.read(authProvider).valueOrNull;
        if (auth is AuthAuthenticated) {
          context.push('/provider/${auth.userId}');
        }
        break;
    }
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'request_response':
        return Icons.assignment_rounded;
      case 'question_received':
        return Icons.help_rounded;
      case 'rating_received':
        return Icons.star_rounded;
      case 'recommendation_received':
        return Icons.thumb_up_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
          leading: const AppBackButton(), title: const Text('Notificações')),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Nenhuma notificação ainda'))
            : AppScrollbar(
                controller: _scrollCtrl,
                child: ListView.separated(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final n = list[i];
                    final isUnread = n['read'] == false;
                    return Card(
                      color: isUnread ? AppColors.primary50 : null,
                      elevation: isUnread ? 1 : 0,
                      child: ListTile(
                        leading: Icon(_iconFor(n['type'] as String?),
                            color: AppColors.primary),
                        title: Text(n['title'] as String? ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(n['body'] as String? ?? ''),
                        onTap: () => _onTap(n),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
