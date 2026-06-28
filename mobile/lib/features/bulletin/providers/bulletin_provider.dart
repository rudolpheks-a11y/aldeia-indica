import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/bulletin_repository.dart';

final bulletinRepoProvider = Provider((ref) {
  final api = ref.watch(apiClientProvider);
  return BulletinRepository(api);
});

final bulletinProvider =
    FutureProvider<List<BulletinPost>>((ref) async {
  return ref.watch(bulletinRepoProvider).listApproved();
});

final bulletinPendingProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(bulletinRepoProvider).listPending();
});
