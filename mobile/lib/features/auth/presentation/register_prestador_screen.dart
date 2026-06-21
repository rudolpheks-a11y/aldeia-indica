import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';

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

class RegisterPrestadorScreen extends ConsumerStatefulWidget {
  const RegisterPrestadorScreen({super.key});

  @override
  ConsumerState<RegisterPrestadorScreen> createState() =>
      _RegisterPrestadorScreenState();
}

class _RegisterPrestadorScreenState
    extends ConsumerState<RegisterPrestadorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String? _selectedCommunity;
  String? _selectedCondominio;
  int _years = 0;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _passwordCtrl, _bioCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.registerPrestador(
        communityId: _comunidades[_selectedCommunity!]!,
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text.trim(),
        city: _selectedCondominio!,
        yearsInNeighborhood: _years,
        professionalBio: _bioCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cadastro enviado! Aguarde aprovação.')),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Prestador')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                decoration: const InputDecoration(labelText: 'Nome completo'),
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
                validator: (v) => v == null ? 'Selecione o condomínio' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Anos atuando no bairro:'),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: _years,
                    items: List.generate(
                      31,
                      (i) => DropdownMenuItem(value: i, child: Text('$i')),
                    ),
                    onChanged: (v) => setState(() => _years = v ?? 0),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição profissional',
                  hintText: 'Conte sua experiência...',
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _register,
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
    );
  }
}
