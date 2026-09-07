import 'package:flutter/foundation.dart';
import '/services/base.dart';
import '/types/sync.dart';

abstract class BaseSyncService extends ChangeNotifier with BaseService {
  /// Gets release info from the server.
  Future<ReleaseInfo?> getRelease();
}
