import 'package:flutter/material.dart';
import '../../../shared/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scrollbar.dart';
import '../../providers_list/providers/search_provider.dart';
import '../providers/request_providers.dart';

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() =>
      _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _category = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(apiClientProvider).post(ApiEndpoints.requests, data: {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category_slug': _category,
      });
      // O pedido novo precisa aparecer na lista assim que o usuário volta.
      ref.invalidate(requestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido publicado!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível publicar o pedido. Tente novamente.'), backgroundColor: AppColors.error900),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Novo Pedido de Serviço')),
      body: AppScrollbar(
        controller: _scrollCtrl,
        child: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'O que você precisa?',
                hintText: 'Ex: Preciso de eletricista amanhã',
              ),
            ),
            const SizedBox(height: 16),
            // Se as categorias não carregarem, o campo some e o pedido sai
            // sem categoria ("Geral") — nunca bloqueia a publicação.
            categories.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Categoria (opcional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Geral (sem categoria)')),
                    ...list.map((c) => DropdownMenuItem(
                        value: c.slug, child: Text(c.namePt))),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? ''),
                ),
              ),
            ),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detalhes (opcional)',
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Publicar pedido'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
