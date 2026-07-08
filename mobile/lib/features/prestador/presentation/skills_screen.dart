import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/app_scrollbar.dart';
import '../providers/prestador_provider.dart';
import '../../provider_profile/providers/profile_provider.dart';
import '../../providers_list/providers/search_provider.dart';
import '../../../shared/widgets/app_error_view.dart';

class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  Set<String> _selectedSlugs = {};
  bool _needsTransport = false;
  String? _transportType;
  bool _loaded = false;
  bool _saving = false;
  String _query = '';
  final _searchCtrl = TextEditingController();
  final _listCtrl = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(prestadorProfileProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    profileAsync.whenData((profile) {
      if (!_loaded) {
        _selectedSlugs = Set.from(profile.categorySlugs);
        _needsTransport = profile.needsTransport;
        _transportType = profile.transportType;
        _loaded = true;
      }
    });

    return LoadingOverlay(
      isLoading: _saving,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Cadastre suas habilidades'),
        ),
        body: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: AppErrorView(onRetry: () => ref.invalidate(categoriesProvider))),
          data: (categories) => _buildBody(context, categories),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<ServiceCategory> categories) {
    final filtered = _query.isEmpty
        ? categories
        : categories
            .where((c) => c.namePt.toLowerCase().contains(_query))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar serviço...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: AppScrollbar(
            controller: _listCtrl,
            child: ListView(
            controller: _listCtrl,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              if (_query.isEmpty) ...[
                Text(
                  'Selecione os serviços que você oferece:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
              ],
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Nenhum serviço encontrado.')),
                ),
              ...filtered.map((cat) => CheckboxListTile(
                    value: _selectedSlugs.contains(cat.slug),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selectedSlugs.add(cat.slug);
                      } else {
                        _selectedSlugs.remove(cat.slug);
                      }
                    }),
                    title: Text(cat.namePt),
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  )),
              if (_query.isEmpty) ...[
              const Divider(height: 32),
              Text(
                'Necessidade de transporte:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _needsTransport,
                onChanged: (v) => setState(() {
                  _needsTransport = v;
                  if (!v) _transportType = null;
                }),
                title: const Text('Preciso de auxílio com transporte'),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              if (_needsTransport) ...[
                const SizedBox(height: 8),
                RadioListTile<String>(
                  value: 'public',
                  groupValue: _transportType,
                  onChanged: (v) => setState(() => _transportType = v),
                  title: const Text('Transporte público'),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  value: 'fuel',
                  groupValue: _transportType,
                  onChanged: (v) => setState(() => _transportType = v),
                  title: const Text('Auxílio com combustível'),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              const SizedBox(height: 24),
              ], // fim if (_query.isEmpty) — seção de transporte
              if (_query.isNotEmpty) const SizedBox(height: 16),
            ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: const Text('Salvar'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_needsTransport && _transportType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o tipo de auxílio com transporte.'),
          backgroundColor: AppColors.error900,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(prestadorRepositoryProvider).updateSkills(
            categorySlugs: _selectedSlugs.toList(),
            needsTransport: _needsTransport,
            transportType: _transportType,
          );
      ref.invalidate(prestadorProfileProvider);
      invalidateOwnProviderData(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Habilidades salvas com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível salvar. Tente novamente.'),
            backgroundColor: AppColors.error900,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
