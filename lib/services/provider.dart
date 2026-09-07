import 'package:flutter/foundation.dart';
import '/services/courses/base.dart';
import '/services/widget_updater.dart';
import '/services/courses/ustb_byyt.dart';
import '/services/courses/exceptions.dart';
import '/services/store/base.dart';
import '/services/store/general.dart';
import '/services/net/base.dart';
import '/services/net/drcom_net.dart';
import '/services/sync/base.dart';
import '/services/sync/sync_service.dart';
import '/types/courses.dart';
import '/types/preferences.dart';


class ServiceProvider extends ChangeNotifier {
  final List<VoidCallback> _serviceListenerDisposers = [];

  // Course Service
  late BaseCoursesService _coursesService;

  // Net Service
  late BaseNetService _netService;

  // Sync Service
  late BaseSyncService _syncService;

  // Store Service
  late BaseStoreService _storeService;

  // Singleton
  static final ServiceProvider _instance = ServiceProvider._internal();
  static ServiceProvider get instance => _instance;

  ServiceProvider._internal() {
    _coursesService = UstbByytService();
    _netService = DrcomNetService();
    _syncService = SyncService();
    _storeService = GeneralStoreService();

    _bindService(_coursesService);
    _bindService(_netService);
    _bindService(_syncService);
  }

  BaseCoursesService get coursesService => _coursesService;

  BaseNetService get netService => _netService;

  BaseSyncService get syncService => _syncService;

  BaseStoreService get storeService => _storeService;

  /// Notify listeners when app settings change (e.g. exam/holiday mode toggled).
  void notifySettingsChanged() => notifyListeners();

  Future<void> initializeServices() async {
    await _storeService.initialize();

    // Try to restore login from cache after store service is initialized
    await _tryAutoLogin();

    // Try to load curriculum data after login
    if (coursesService.isOnline) {
      await _loadCurriculumData();
    }
  }

  Future<void> _loadCurriculumData() async {
    try {
      // Check cache
      final cachedData = storeService.getConfig<CurriculumIntegratedData>(
        "curriculum_data",
        CurriculumIntegratedData.fromJson,
      );

      if (cachedData == null) {
        // Load fresh curriculum data
        await getCurriculumData();
      }
    } catch (e) {
      // Ignore errors during background loading
    }
  }

  Future<CurriculumIntegratedData?> getCurriculumData([
    TermInfo? termInfo,
  ]) async {
    final cachedData = storeService.getConfig<CurriculumIntegratedData>(
      "curriculum_data",
      CurriculumIntegratedData.fromJson,
    );

    if (cachedData != null) {
      return cachedData;
    }

    final appSettings =
        storeService.getPref<AppSettings>('app_settings', AppSettings.fromJson);
    if (appSettings?.holidayMode == true || appSettings?.examMode == true) {
      return null;
    }

    if (!coursesService.isOnline) {
      return null;
    }

    if (termInfo != null) {
      try {
        return await loadCurriculumForTerm(termInfo);
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  Future<CurriculumIntegratedData> loadCurriculumForTerm(
    TermInfo termInfo,
  ) async {
    if (!coursesService.isOnline) {
      throw const CourseServiceOffline();
    }

    final calendarFuture = termInfo.season >= 3
        ? Future.value(<CalendarDay>[])
        : coursesService
            .getCalendarDays(termInfo)
            .catchError((e) => <CalendarDay>[]);

    final futures = await Future.wait([
      coursesService.getCurriculum(termInfo),
      coursesService.getCoursePeriods(termInfo),
      calendarFuture,
    ]);

    final classes = futures[0] as List<ClassItem>;
    final periods = futures[1] as List<ClassPeriod>;
    final calendarDays = futures[2] as List<CalendarDay>;

    final integratedData = CurriculumIntegratedData(
      currentTerm: termInfo,
      allClasses: classes,
      allPeriods: periods,
      calendarDays: calendarDays.isEmpty ? null : calendarDays,
    );

    // Cache the data
    storeService.putConfig<CurriculumIntegratedData>(
      "curriculum_data",
      integratedData,
    );

    // Read custom courses for this term
    final customCoursesKey = 'custom_courses_${termInfo.year}_${termInfo.season}';
    final customCoursesData = storeService.getPref<CustomCoursesList>(
      customCoursesKey,
      CustomCoursesList.fromJson,
    );

    // Update widget with custom courses merged
    WidgetUpdater().updateFromCurriculum(
      integratedData,
      customCourses: customCoursesData?.courses,
    );

    // Auto-disable holiday/exam mode when fresh curriculum loaded
    final appSettings = storeService.getPref<AppSettings>(
      'app_settings',
      AppSettings.fromJson,
    );
    if (appSettings?.holidayMode == true || appSettings?.examMode == true) {
      storeService.putPref<AppSettings>(
        'app_settings',
        AppSettings(
          themeMode: appSettings!.themeMode,
          accentColorValue: appSettings.accentColorValue,
          holidayMode: false,
          examMode: false,
        ),
      );
    }

    return integratedData;
  }


  //

  //

  /// Try to restore login from cache on app startup
  Future<void> _tryAutoLogin() async {
    try {
      final cachedData = _storeService.getConfig<UserLoginIntegratedData>(
        "course_account_data",
        UserLoginIntegratedData.fromJson,
      );

      if (cachedData == null) return;

      final data = cachedData;
      final method = data.method;

      if (method == "cookie" || method == "sso") {
        if (data.cookie != null && data.user != null) {
          await _coursesService.login(data.cookie!);
          // Get new user info and verify consistency
          final newUserInfo = await coursesService.getUserInfo();
          assert(
            newUserInfo == data.user,
            "User info mismatch after auto-login with cached cookie",
          );
        }
      }
      // Other methods: do nothing, remain logged out
    } catch (e) {
      // On any exception, remain logged out, auto-login should be silent
      if (kDebugMode) {
        print('Auto-login failed: $e');
      }
    }
  }

  @override
  void dispose() {
    for (final disposer in _serviceListenerDisposers) {
      disposer();
    }
    super.dispose();
  }

  void _bindService(Listenable service) {
    void forward() => notifyListeners();
    service.addListener(forward);
    _serviceListenerDisposers.add(() {
      service.removeListener(forward);
    });
  }

}
