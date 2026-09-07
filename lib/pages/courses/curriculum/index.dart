import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import '/services/provider.dart';
import '/types/courses.dart';
import '/types/preferences.dart';
import '/utils/app_bar.dart';
import '/services/widget_updater.dart';
import '/utils/sync_embeded.dart';
import '/utils/haptic.dart';
import '/utils/navigation.dart';
import 'common.dart';
import 'table.dart';
import 'custom_course_dialog.dart';

class MajorPeriodInfo {
  final int id;
  final String name;
  final String startTime;
  final String endTime;

  MajorPeriodInfo(this.id, this.name, this.startTime, this.endTime);
}

class CurriculumPage extends StatefulWidget {
  const CurriculumPage({super.key});

  @override
  State<CurriculumPage> createState() => _CurriculumPageState();
}

class _CurriculumPageState extends State<CurriculumPage>
    with TickerProviderStateMixin {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  CurriculumIntegratedData? _curriculumData;
  String? _errorMessage;
  int _currentWeek = 1;
  int _previousWeek = 0;
  bool _isLoading = false;
  List<ClassItem> _customCourses = [];
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _serviceProvider.addListener(_onServiceStatusChanged);

    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.linear),
    );

    _loadCurriculumFromCacheOrService();
  }

  String _customCoursesKey(TermInfo term) =>
      'custom_courses_${term.year}_${term.season}';

  List<ClassItem> _readCustomCourses(TermInfo term) {
    final data = _serviceProvider.storeService.getPref<CustomCoursesList>(
      _customCoursesKey(term),
      CustomCoursesList.fromJson,
    );
    return data?.courses ?? [];
  }

  void _saveCustomCourses(TermInfo term) {
    _serviceProvider.storeService.putPref<CustomCoursesList>(
      _customCoursesKey(term),
      CustomCoursesList(courses: _customCourses),
    );
    // Update widgets so custom courses appear immediately
    final cached = _serviceProvider.storeService.getConfig<CurriculumIntegratedData>(
      'curriculum_data',
      CurriculumIntegratedData.fromJson,
    );
    if (cached != null) {
      WidgetUpdater().updateFromCurriculum(cached, customCourses: _customCourses);
    }
  }

  CurriculumIntegratedData _getMergedData(CurriculumIntegratedData base) {
    return CurriculumIntegratedData(
      currentTerm: base.currentTerm,
      allClasses: [...base.allClasses, ..._customCourses],
      allPeriods: base.allPeriods,
      calendarDays: base.calendarDays,
      summerTermStartDate: base.summerTermStartDate,
    );
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _serviceProvider.removeListener(_onServiceStatusChanged);
    super.dispose();
  }

  CurriculumSettings getSettings() {
    final cached = _serviceProvider.storeService.getPref<CurriculumSettings>(
      "curriculum",
      CurriculumSettings.fromJson,
    );
    return CurriculumSettings(
      weekendMode: WeekendDisplayMode.auto,
      tableSize: TableSize.small,
      animationMode: AnimationMode.slide,
      activated: cached?.activated ?? true,
    );
  }

  void saveSettings(CurriculumSettings settings) {
    _serviceProvider.storeService.putPref<CurriculumSettings>(
      "curriculum",
      settings,
    );
  }

  void _onServiceStatusChanged() {
    if (mounted && _serviceProvider.coursesService.isOnline) {
      setState(() {
        _loadCurriculumFromCacheOrService();
      });
    }
  }

  Future<void> _loadCurriculumFromCacheOrService() async {
    final cachedData = _serviceProvider.storeService
        .getConfig<CurriculumIntegratedData>(
          "curriculum_data",
          CurriculumIntegratedData.fromJson,
        );

    if (cachedData != null) {
      if (mounted) {
        _customCourses = _readCustomCourses(cachedData.currentTerm);
        setState(() {
          _curriculumData = cachedData;
          _errorMessage = null;
          _gotoCurrentDateWeek();
        });
        _fadeAnimationController.forward();
      }
      return;
    }

    final service = _serviceProvider.coursesService;
    if (!service.isOnline) {
      if (mounted) {
        setState(() {
          _curriculumData = null;
          _errorMessage = null;
        });
      }
      return;
    }
  }

  Future<void> _loadCurriculumForTerm(TermInfo termInfo) async {
    final service = _serviceProvider.coursesService;

    if (!service.isOnline) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final calendarFuture = termInfo.season >= 3
          ? Future.value(<CalendarDay>[])
          : service.getCalendarDays(termInfo).catchError((e) => <CalendarDay>[]);

      final futures = await Future.wait([
        service.getCurriculum(termInfo),
        service.getCoursePeriods(termInfo),
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

      _serviceProvider.storeService.putConfig<CurriculumIntegratedData>(
        "curriculum_data",
        integratedData,
      );

      _autoDisableHolidayMode();

      if (mounted) {
        _customCourses = _readCustomCourses(integratedData.currentTerm);
        setState(() {
          _curriculumData = integratedData;
          _isLoading = false;
          _gotoCurrentDateWeek();
        });
        _fadeAnimationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _autoDisableHolidayMode() {
    final appSettings = _serviceProvider.storeService.getPref<AppSettings>(
      'app_settings',
      AppSettings.fromJson,
    );
    if (appSettings?.holidayMode == true || appSettings?.examMode == true) {
      _serviceProvider.storeService.putPref<AppSettings>(
        'app_settings',
        AppSettings(
          themeMode: appSettings!.themeMode,
          accentColorValue: appSettings.accentColorValue,
          holidayMode: false,
          examMode: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: '课表',
        actions: _curriculumData != null
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.icon(
                    onPressed: () {
                      Haptics.light();
                      _showSwitchTermDialog();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('刷新课表'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: SyncPowered(childBuilder: (context) => _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              '加载失败: $_errorMessage',
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                Haptics.light();
                _refreshCurriculumData();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final cachedData = _serviceProvider.storeService
        .getConfig<CurriculumIntegratedData>(
          "curriculum_data",
          CurriculumIntegratedData.fromJson,
        );

    if (cachedData != null) {
      final data = cachedData;
      if (mounted && _curriculumData != data) {
        _customCourses = _readCustomCourses(data.currentTerm);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _curriculumData = data;
            _gotoCurrentDateWeek();
          });
        });
      }
      return _buildCurriculumView();
    } else {
      if (!_serviceProvider.coursesService.isOnline) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Container(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.login, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                onPressed: () {
                  Haptics.selection();
                  pushPathGuarded(context, '/courses/account');
                },
              ),
              const SizedBox(height: 16),
              Text(
                '请先登录',
                style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      }

      return _buildSelectionView(null);
    }
  }

  Widget _buildSelectionView(CurriculumIntegratedData? cachedData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool shouldUseDoubleColumn = constraints.maxWidth > 1000;

          if (shouldUseDoubleColumn && cachedData != null) {
            // Two column layout
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChooseLatestCard(
                        isLoggedIn: _serviceProvider.coursesService.isOnline,
                        getTerms: () =>
                            _serviceProvider.coursesService.getTerms(),
                        onTermSelected: _loadCurriculumForTerm,
                        useFlexLayout: true,
                        isLoading: _isLoading,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChooseCacheCard(
                        cachedData: cachedData,
                        onSubmit: _activateAndViewCachedData,
                        useFlexLayout: true,
                        isLoading: _isLoading,
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Single column layout
            return Column(
              children: [
                ChooseLatestCard(
                  isLoggedIn: _serviceProvider.coursesService.isOnline,
                  getTerms: () => _serviceProvider.coursesService.getTerms(),
                  onTermSelected: _loadCurriculumForTerm,
                  isLoading: _isLoading,
                ),
                if (cachedData != null)
                  ChooseCacheCard(
                    cachedData: cachedData,
                    onSubmit: _activateAndViewCachedData,
                    isLoading: _isLoading,
                  ),
              ],
            );
          }
        },
      ),
    );
  }

  void _activateAndViewCachedData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final cachedData = _serviceProvider.storeService
        .getConfig<CurriculumIntegratedData>(
          "curriculum_data",
          CurriculumIntegratedData.fromJson,
        );

    if (cachedData != null) {
      final data = cachedData;

      if (mounted) {
        _customCourses = _readCustomCourses(data.currentTerm);
        setState(() {
          _curriculumData = data;
          _isLoading = false;
          _gotoCurrentDateWeek();
        });
        _fadeAnimationController.forward();
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildCurriculumView() {
    if (_curriculumData == null ||
        (_curriculumData!.allClasses.isEmpty && _customCourses.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              '暂无课程数据',
              style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (_curriculumData != null)
              Text(
                '当前查看：${_curriculumData!.currentTerm.year}学年 第${_curriculumData!.currentTerm.season}学期',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                Haptics.light();
                _clearCacheAndSelectTerm();
              },
              child: const Text('重新选择学期'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          _buildWeekSelector(),
          const SizedBox(height: 16),
          Expanded(
            // To avoid animation overflow
            child: ClipRect(
              child: GestureDetector(
                onPanEnd: (details) {
                  if (details.velocity.pixelsPerSecond.dx.abs() > 400) {
                    Haptics.medium();
                    if (details.velocity.pixelsPerSecond.dx > 0) {
                      // Slide from left
                      _gotoWeekSafe(_currentWeek - 1);
                    } else {
                      // Slide from right
                      _gotoWeekSafe(_currentWeek + 1);
                    }
                  }
                },
                child: _buildCurriculumTableWithAnimation(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshCurriculumData() async {
    _serviceProvider.storeService.delConfig("curriculum_data");
    await _loadCurriculumFromCacheOrService();
  }

  Future<void> _clearCacheAndSelectTerm() async {
    _serviceProvider.storeService.delConfig("curriculum_data");
    if (mounted) {
      setState(() {
        _curriculumData = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _onTripleTapEmptyCell(int day, int period) async {
    if (_curriculumData == null) return;
    final maxWeek = _curriculumData!.getMaxValidWeekIndex();
    final effectiveMaxWeek = maxWeek < 16 ? 16 : maxWeek;

    final result = await showDialog(
      context: context,
      builder: (ctx) => CustomCourseDialog(
        day: day,
        period: period,
        maxWeek: effectiveMaxWeek,
      ),
    );

    if (result == null || !mounted) return;

    if (result is ClassItem) {
      setState(() => _customCourses.add(result));
      _saveCustomCourses(_curriculumData!.currentTerm);
    }
  }

  Future<void> _onTapCustomCourse(ClassItem course) async {
    final maxWeek = _curriculumData!.getMaxValidWeekIndex();
    final effectiveMaxWeek = maxWeek < 16 ? 16 : maxWeek;

    final result = await showDialog(
      context: context,
      builder: (ctx) => CustomCourseDialog(
        day: course.day,
        period: course.period,
        maxWeek: effectiveMaxWeek,
        existing: course,
      ),
    );

    if (result == null || !mounted) return;

    if (result == 'delete') {
      setState(() {
        _customCourses.removeWhere((c) =>
            c.day == course.day &&
            c.period == course.period &&
            c.className == course.className &&
            c.locationName == course.locationName);
      });
      _saveCustomCourses(_curriculumData!.currentTerm);
    } else if (result is ClassItem) {
      setState(() {
        final idx = _customCourses.indexWhere((c) =>
            c.day == course.day &&
            c.period == course.period &&
            c.className == course.className &&
            c.locationName == course.locationName);
        if (idx >= 0) _customCourses[idx] = result;
      });
      _saveCustomCourses(_curriculumData!.currentTerm);
    }
  }

  Widget _buildWeekSelector() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            Haptics.selection();
            _gotoWeekSafe(_currentWeek - 1);
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Haptics.selection();
              _showWeekJumper();
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '第 $_currentWeek 周',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        Tooltip(
          message: _currentWeek >= _getMergedData(_curriculumData!).getMaxValidWeekIndex()
              ? '已经到最大周次了~'
              : '',
          child: IconButton(
            onPressed: () {
              Haptics.selection();
              _gotoWeekSafe(_currentWeek + 1);
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ),
      ],
    );
  }

  void _showWeekJumper() {
    final merged = _getMergedData(_curriculumData!);
    final maxValidWeek = merged.getMaxValidWeekIndex();
    final todayWeek = _curriculumData!.getWeekIndexToday();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 8),
            const Text('周次跳转'),
          ],
        ),
        content: SizedBox(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: List.generate(maxValidWeek, (index) {
                  final week = index + 1;
                  final isCurrentWeek = week == _currentWeek;
                  final isTodayWeek = week == todayWeek;

                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$week'),
                        if (isCurrentWeek) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.visibility,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                        if (isTodayWeek && !isCurrentWeek) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.today,
                            size: 18,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ],
                      ],
                    ),
                    selected: false,
                    onSelected: (selected) {
                      Haptics.selection();
                      Navigator.of(context).pop();
                      _gotoWeekSafe(week);
                    },
                    backgroundColor: isCurrentWeek
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.6)
                        : null,
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _gotoWeekSafe(int newWeek) {
    final merged = _getMergedData(_curriculumData!);
    newWeek = newWeek.clamp(1, merged.getMaxValidWeekIndex());

    if (newWeek == _currentWeek) return;

    setState(() {
      _previousWeek = _currentWeek;
      _currentWeek = newWeek;
    });
  }

  void _gotoCurrentDateWeek() {
    final merged = _getMergedData(_curriculumData!);
    final maxValidWeek = merged.getMaxValidWeekIndex();
    if (_currentWeek > maxValidWeek) {
      _currentWeek = maxValidWeek;
    }

    final todayWeek = _curriculumData!.getWeekIndexToday();
    if (todayWeek != null && todayWeek >= 1 && todayWeek <= maxValidWeek) {
      _currentWeek = todayWeek;
    }
  }

  Widget _buildCurriculumTableWithAnimation() {
    final settings = getSettings();
    final animationMode = settings.animationMode;

    final slideDirection = (_currentWeek - _previousWeek).clamp(-1, 1);

    Widget tableContent;

    switch (animationMode) {
      case AnimationMode.fade:
        tableContent = AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _buildCurriculumTable(key: ValueKey(_currentWeek)),
        );
        break;

      case AnimationMode.slide:
        tableContent = AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: Offset(slideDirection * 0.4, 0.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            );
          },
          child: _buildCurriculumTable(key: ValueKey(_currentWeek)),
        );
        break;

      case AnimationMode.none:
        tableContent = _buildCurriculumTable();
        break;
    }

    return AnimatedBuilder(
      animation: _fadeAnimationController,
      builder: (context, child) {
        return FadeTransition(opacity: _fadeAnimation, child: tableContent);
      },
    );
  }

  Widget _buildCurriculumTable({Key? key}) {
    if (_curriculumData == null || _curriculumData!.allPeriods.isEmpty) {
      return Center(
        key: key,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, size: 64, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 16),
            Text(
              '课时数据未加载',
              style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              '无法显示课表时间信息',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                Haptics.light();
                _refreshCurriculumData();
              },
              child: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        try {
          final settings = getSettings();
          final mergedData = _getMergedData(_curriculumData!);
          final weekDates = mergedData.getWeekdayDaysOf(_currentWeek);

          return CurriculumTable(
            curriculumData: mergedData,
            availableWidth: constraints.maxWidth,
            availableHeight: constraints.maxHeight,
            settings: settings,
            weekDates: weekDates,
            currentWeek: _currentWeek,
            onTripleTapEmptyCell: _onTripleTapEmptyCell,
            onTapCustomCourse: _onTapCustomCourse,
          );
        } catch (e) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  '课表构建失败: $e',
                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () {
                    Haptics.light();
                    _refreshCurriculumData();
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  void _showSwitchTermDialog() {
    final cachedData = _serviceProvider.storeService
        .getConfig<CurriculumIntegratedData>(
          "curriculum_data",
          CurriculumIntegratedData.fromJson,
        );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刷新课表'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChooseLatestCard(
                  isLoggedIn: _serviceProvider.coursesService.isOnline,
                  getTerms: () => _serviceProvider.coursesService.getTerms(),
                  onTermSelected: (termInfo) {
                    Navigator.of(context).pop();
                    _loadCurriculumForTerm(termInfo);
                  },
                  isLoading: _isLoading,
                ),
                if (cachedData != null)
                  ChooseCacheCard(
                    cachedData: cachedData,
                    onSubmit: () {
                      Navigator.of(context).pop();
                      _activateAndViewCachedData();
                    },
                    isLoading: _isLoading,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
