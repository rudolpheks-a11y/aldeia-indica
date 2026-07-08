import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_scrollbar.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/bulletin_provider.dart';
import '../../../shared/widgets/app_error_view.dart';

class BulletinScreen extends ConsumerStatefulWidget {
  const BulletinScreen({super.key});

  @override
  ConsumerState<BulletinScreen> createState() => _BulletinScreenState();
}

class _BulletinScreenState extends ConsumerState<BulletinScreen> {
  final _ctrl = TextEditingController();
  final _listCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(bulletinRepoProvider).create(text);
      _ctrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Aviso enviado! Aguardando aprovação do administrador.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar o aviso. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(bulletinProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Mural de Avisos'),
      ),
      body: Column(
        children: [
          Expanded(
            child: posts.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(child: AppErrorView(onRetry: () => ref.invalidate(bulletinProvider))),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Nenhum aviso ainda.',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : AppScrollbar(
                      controller: _listCtrl,
                      child: ListView.separated(
                      controller: _listCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final p = list[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(p.authorName,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(p.content,
                                    style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    maxLines: 3,
                    minLines: 1,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText: 'Escreva um aviso para a comunidade...',
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: _sending ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
