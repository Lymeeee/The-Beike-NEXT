import '/services/sync/base.dart';
import '/types/sync.dart';

class SyncService extends BaseSyncService {
  @override
  String get defaultBaseUrl => '';

  @override
  Future<ReleaseInfo?> getRelease() async {
    return null;
  }
}
