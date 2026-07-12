import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/contact_admin_button.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../core/constants/app_colors.dart';

const _comunidades = {
  'Aldeia da Serra': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
};

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _selectedCommunity;
  bool _obscurePassword = true;
  // Loading é local: mandar o authProvider pra loading recriaria o GoRouter
  // (o routerProvider observa o authProvider) e a tela seria destruída no meio
  // da tentativa de login.
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref.read(authProvider.notifier).login(
          communityId: _comunidades[_selectedCommunity!]!,
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case LoginOk():
        break; // o redirect do go_router leva pra home
      case LoginDeletedAccount(:final message):
        await _offerReactivation(message);
      case LoginFailed(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error900),
        );
    }
  }

  Future<void> _offerReactivation(String message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reativar conta'),
        content: Text(
          '$message\n\n'
          'Ao reativar, você volta com o mesmo perfil e o mesmo histórico de '
          'avaliações de antes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Agora não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reativar minha conta'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _loading = true);
    final result = await ref.read(authProvider.notifier).reactivate(
          communityId: _comunidades[_selectedCommunity!]!,
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result case LoginFailed(:final message)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error900),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  SvgPicture.asset(
                    'assets/branding/logo-stacked.svg',
                    height: 200,
                    semanticsLabel: 'Aldeia Indica',
                  ),
                  const SizedBox(height: 32),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 6
                        ? 'Mínimo 6 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: const Text('Entrar'),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Esqueci minha senha'),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => context.push('/register/morador'),
                        child: const Text('Sou morador'),
                      ),
                      const Text('·'),
                      TextButton(
                        onPressed: () => context.push('/register/prestador'),
                        child: const Text('Sou prestador'),
                      ),
                    ],
                  ),
                  const ContactAdminTextButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
