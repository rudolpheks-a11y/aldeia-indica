import 'package:flutter/material.dart';
import '../../../shared/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/app_scrollbar.dart';
import '../../../core/constants/app_colors.dart';

const _comunidades = {
  'Aldeia da Serra': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
};

const _condominios = [
  'Morada dos Pinheiros',
  'Morada dos Pássaros',
  'Morada das Flores',
  'Morada dos Lagos',
  'Morada das Estrelas',
  'Condomínio Altavis',
  'Morada da Serra',
  'Morada da Aldeia',
  'Morada das Nuvens',
  'Mosaico da Aldeia',
  'Outros',
];

class RegisterMoradorScreen extends ConsumerStatefulWidget {
  const RegisterMoradorScreen({super.key});

  @override
  ConsumerState<RegisterMoradorScreen> createState() =>
      _RegisterMoradorScreenState();
}

class _RegisterMoradorScreenState
    extends ConsumerState<RegisterMoradorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _inviteCode1Ctrl = TextEditingController();
  final _inviteCode2Ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _selectedCommunity;
  String? _selectedCondominio;
  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _passwordCtrl,
      _inviteCode1Ctrl,
      _inviteCode2Ctrl
    ]) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).registerMorador(
            communityId: _comunidades[_selectedCommunity!]!,
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            fullName: _nameCtrl.text.trim(),
            streetAddress: _selectedCondominio!,
            houseNumber: '',
            inviteCode1: _inviteCode1Ctrl.text.trim(),
            inviteCode2: _inviteCode2Ctrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cadastro concluído! Você já pode entrar.')),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error900),
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
        appBar: AppBar(leading: const AppBackButton(), title: const Text('Cadastro de Morador')),
        body: AppScrollbar(
          controller: _scrollCtrl,
          child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedCommunity,
                  decoration: const InputDecoration(labelText: 'Comunidade'),
                  items: _comunidades.keys
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCommunity = v),
                  validator: (v) => v == null ? 'Selecione a comunidade' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nome completo'),
                  validator: (v) => v?.isEmpty == true ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: (v) =>
                      v?.contains('@') == true ? null : 'E-mail inválido',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  validator: (v) =>
                      v != null && v.length >= 6 ? null : 'Mínimo 6 caracteres',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCondominio,
                  decoration: const InputDecoration(labelText: 'Condomínio'),
                  items: _condominios
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCondominio = v),
                  validator: (v) =>
                      v == null ? 'Selecione o condomínio' : null,
                ),
                const SizedBox(height: 24),
                Text(
                  'Peça a 2 moradores da sua comunidade um código de convite '
                  '(eles geram na home do app, em "Convidar morador").',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _inviteCode1Ctrl,
                  decoration: const InputDecoration(
                      labelText: 'Código de convite (morador 1)'),
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _inviteCode2Ctrl,
                  decoration: const InputDecoration(
                      labelText: 'Código de convite (morador 2)'),
                  validator: (v) =>
                      v?.trim().isEmpty == true ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: const Text('Cadastrar'),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Já tenho cadastro'),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
