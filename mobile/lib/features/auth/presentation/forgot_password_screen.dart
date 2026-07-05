import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/app_scrollbar.dart';

const _comunidades = {
  'Aldeia da Serra': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
};

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _selectedCommunity;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.forgotPassword(
        communityId: _comunidades[_selectedCommunity!]!,
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      context.push('/reset-password', extra: {
        'communityId': _comunidades[_selectedCommunity!]!,
        'email': _emailCtrl.text.trim(),
      });
    } catch (_) {
      // Even on error, navigate — don't reveal if email exists
      if (!mounted) return;
      context.push('/reset-password', extra: {
        'communityId': _comunidades[_selectedCommunity!]!,
        'email': _emailCtrl.text.trim(),
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Recuperar senha')),
        body: SafeArea(
          child: AppScrollbar(
            controller: _scrollCtrl,
            child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Informe sua comunidade e e-mail. Você receberá um código de 6 dígitos para criar uma nova senha.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: _selectedCommunity,
                    decoration: const InputDecoration(
                      labelText: 'Comunidade',
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    items: _comunidades.keys
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCommunity = v),
                    validator: (v) =>
                        v == null ? 'Selecione a comunidade' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'E-mail inválido' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: const Text('Enviar código'),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
