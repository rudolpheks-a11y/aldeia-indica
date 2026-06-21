import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/loading_overlay.dart';

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
  String? _selectedCommunity;
  String? _selectedCondominio;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _passwordCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).registerMorador(
          communityId: _comunidades[_selectedCommunity!]!,
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          fullName: _nameCtrl.text.trim(),
          streetAddress: _selectedCondominio!,
          houseNumber: '',
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.isLoading;

    ref.listen(authProvider, (_, next) {
      final state = next.valueOrNull;
      if (state is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message), backgroundColor: Colors.red),
        );
      }
    });

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Cadastro de Morador')),
        body: SingleChildScrollView(
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
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isLoading ? null : _register,
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
    );
  }
}
