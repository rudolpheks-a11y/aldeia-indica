import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/prestador_repository.dart';
import '../../auth/providers/auth_provider.dart';

final prestadorRepositoryProvider = Provider((ref) {
  return PrestadorRepository(ref.watch(apiClientProvider));
});

final prestadorProfileProvider = FutureProvider<PrestadorProfile>((ref) async {
  return ref.watch(prestadorRepositoryProvider).getProfile();
});
