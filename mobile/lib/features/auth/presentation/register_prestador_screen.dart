import 'package:flutter/material.dart';
import '../../../shared/widgets/app_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scrollbar.dart';

const _comunidades = {
  'Aldeia da Serra': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
};

const _servicos = [
  'Diarista',
  'Mensalista',
  'Cozinheira',
  'Jardineiro',
  'Encanador',
  'Eletricista',
  'Pedreiro',
  'Serviços Gerais',
  'Pintor',
  'Personal Trainer',
  'Massagista',
  'Fisioterapeuta',
  'Psicólogo',
  'Enfermeira',
  'Cuidadora',
  'Babá',
  'Motorista',
  'Outros',
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
  final _outrosCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _selectedCommunity;
  final Set<String> _selectedServicos = {};
  int _years = 0;
  bool _ratingsAcknowledged = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _passwordCtrl, _outrosCtrl]) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool get _outrosSelecionado => _selectedServicos.contains('Outros');

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServicos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ao menos um serviço'),
          backgroundColor: AppColors.error900,
        ),
      );
      return;
    }

    final servicosList = _selectedServicos.where((s) => s != 'Outros').toList();
    if (_outrosSelecionado && _outrosCtrl.text.trim().isNotEmpty) {
      servicosList.add(_outrosCtrl.text.trim());
    }

    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.registerPrestador(
        communityId: _comunidades[_selectedCommunity!]!,
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text.trim(),
        city: 'Aldeia da Serra',
        yearsInNeighborhood: _years,
        professionalBio: servicosList.join(', '),
        ratingsAcknowledged: _ratingsAcknowledged,
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
          const SnackBar(content: Text('Não foi possível concluir o cadastro. Verifique os dados e tente novamente.'), backgroundColor: AppColors.error900),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: const Text('Cadastro de Prestador')),
      body: AppScrollbar(
        controller: _scrollCtrl,
        child: SingleChildScrollView(
        controller: _scrollCtrl,
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
              const SizedBox(height: 20),
              const Text(
                'Serviços oferecidos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _servicos.map((servico) {
                  final selecionado = _selectedServicos.contains(servico);
                  return FilterChip(
                    label: Text(servico),
                    selected: selecionado,
                    selectedColor: colorScheme.primaryContainer,
                    checkmarkColor: colorScheme.onPrimaryContainer,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedServicos.add(servico);
                        } else {
                          _selectedServicos.remove(servico);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              if (_outrosSelecionado) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  child: TextFormField(
                    controller: _outrosCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Qual serviço você oferece?',
                      hintText: 'Ex: Costureira, Chef de cozinha...',
                      border: InputBorder.none,
                    ),
                    validator: (v) => _outrosSelecionado && (v == null || v.isEmpty)
                        ? 'Descreva o serviço'
                        : null,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // ── Aviso sobre avaliações públicas + aceite obrigatório ──────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sobre as avaliações dos moradores',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No Aldeia Indica, a confiança da comunidade é construída '
                      'por avaliações. Ao concluir seu cadastro como prestador:\n\n'
                      '•  Moradores que contratarem seus serviços poderão '
                      'avaliá-los com notas e comentários.\n'
                      '•  Essas avaliações ficam públicas no seu perfil, '
                      'visíveis para todos os moradores da comunidade.\n'
                      '•  As avaliações alimentam o seu Score Aldeia, a nota '
                      'que ordena os prestadores nas buscas.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              CheckboxListTile(
                value: _ratingsAcknowledged,
                onChanged: (v) =>
                    setState(() => _ratingsAcknowledged = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Li e estou ciente de que meus serviços poderão ser '
                  'avaliados pelos moradores e que essas avaliações serão '
                  'públicas no meu perfil.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                // Sem o aceite, o cadastro não anda (o backend também exige).
                onPressed: _ratingsAcknowledged ? _register : null,
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
