import 'dart:async';
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import '/utils/page_mixins.dart';
import '/utils/haptic.dart';
import '/utils/navigation.dart';
import '/utils/exam_helper.dart';
import '/services/widget_updater.dart';
import '/types/courses.dart';
import '/types/preferences.dart';

class _FeatureCardConfig {
  final String title;
  final String description;
  final IconData icon;
  final Color Function(BuildContext) color;
  final String route;

  _FeatureCardConfig({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with PageStateMixin, LoadingStateMixin {
  static const _noBorderShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  UserInfo? _userInfo;

  ClassItem? _ongoingClass;
  ClassItem? _upcomingClass;
  CurriculumIntegratedData? _curriculumData;
  ExamInfo? _ongoingExam;
  ExamInfo? _upcomingExam;
  Timer? _shortRefreshTimer;
  // Feature card configurations
  late final List<_FeatureCardConfig> _courseFeatureCards = [
    _FeatureCardConfig(
      title: '选课',
      description: '查看和管理课程',
      icon: Icons.school,
      color: (c) => Theme.of(c).colorScheme.primary,
      route: '/courses/selection',
    ),
    _FeatureCardConfig(
      title: '考试',
      description: '查看考试时间和地点',
      icon: Icons.assignment,
      color: (c) => Theme.of(c).colorScheme.primary,
      route: '/courses/exam',
    ),
    _FeatureCardConfig(
      title: '成绩',
      description: '查看考试成绩',
      icon: Icons.assessment,
      color: (c) => Theme.of(c).colorScheme.primary,
      route: '/courses/grade',
    ),
  ];

  late final List<_FeatureCardConfig> _netFeatureCards = [
    _FeatureCardConfig(
      title: '网络服务',
      description: '账户管理和账单查询',
      icon: Icons.wifi,
      color: (c) => Theme.of(c).colorScheme.primary,
      route: '/net/dashboard',
    ),
    _FeatureCardConfig(
      title: '流量查询',
      description: '查看流量与费用明细',
      icon: Icons.swap_horiz,
      color: (c) => Theme.of(c).colorScheme.primary,
      route: '/net/traffic',
    ),
    _FeatureCardConfig(
      title: '电费查询',
      description: '查询宿舍电表余额',
      icon: Icons.bolt,
      color: (c) => Theme.of(c).colorScheme.primary,
      route: '/net/electricity',
    ),
    _FeatureCardConfig(
      title: 'WebVPN',
      description: '在校园网之外访问校内资源',
      icon: Icons.public,
      color: (c) => Theme.of(c).colorScheme.primary,
      route: '/net/webvpn',
    ),
  ];

  late final _FeatureCardConfig _emptyClassroomCard = _FeatureCardConfig(
    title: '无课教室',
    description: '查询空闲自习教室',
    icon: Icons.meeting_room_outlined,
    color: (c) => Theme.of(c).colorScheme.primary,
    route: '/net/empty-classroom',
  );

  @override
  void onServiceInit() {
    _loadUserInfo();
    _loadCurriculumData();
    _loadExamData();
    _startTimers();
  }

  @override
  void onServiceStatusChanged() {
    // Schedule the state update for the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
        _loadUserInfo();
        _loadCurriculumData();
        _loadExamData();
      }
    });
  }

  @override
  void dispose() {
    _shortRefreshTimer?.cancel();
    super.dispose();
  }

  void _startTimers() {
    _shortRefreshTimer?.cancel();
    _shortRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadCurriculumData();
      }
    });

  }

  Future<void> _loadUserInfo() async {
    final service = serviceProvider.coursesService;

    if (!service.isOnline) {
      if (mounted) {
        setState(() {
          _userInfo = null;
        });
      }
      return;
    }

    try {
      final userInfo = await serviceProvider.coursesService.getUserInfo();
      if (mounted) {
        setState(() {
          _userInfo = userInfo;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userInfo = null;
        });
      }
    }
  }

  bool _getExamModeEnabled() {
    final prefs = serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    return prefs?.examMode ?? false;
  }

  bool _getHolidayModeEnabled() {
    final prefs = serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    return prefs?.holidayMode ?? false;
  }

  void _loadExamData() {
    final cached = serviceProvider.storeService.getPref<CachedExamList>(
      'cached_exams',
      CachedExamList.fromJson,
    );
    if (cached != null && mounted) {
      final exams = cached.exams;
      setState(() {
        _ongoingExam = ExamHelper.getOngoingExam(exams);
        _upcomingExam = ExamHelper.getUpcomingExam(exams);
      });
    }
  }

  Future<void> _loadCurriculumData() async {
    try {
      final curriculumData = await serviceProvider.getCurriculumData();

      if (mounted) {
        final newOngoingClass = curriculumData?.getClassOngoing();
        final newUpcomingClass = curriculumData?.getClassUpcoming();

        if (curriculumData != null) {
          WidgetUpdater().updateFromCurriculum(curriculumData);
        } else if (_getHolidayModeEnabled()) {
          WidgetUpdater().updateHoliday();
        } else if (_getExamModeEnabled()) {
          final cachedExams = serviceProvider.storeService.getPref<CachedExamList>(
            'cached_exams',
            CachedExamList.fromJson,
          );
          if (cachedExams != null) {
            WidgetUpdater().updateExams(cachedExams.exams);
          }
        } else {
          WidgetUpdater().updateFromCurriculum(null);
        }

        if (_ongoingClass != newOngoingClass ||
            _upcomingClass != newUpcomingClass ||
            _curriculumData != curriculumData) {
          setState(() {
            _curriculumData = curriculumData;
            _ongoingClass = newOngoingClass;
            _upcomingClass = newUpcomingClass;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _curriculumData = null;
          _ongoingClass = null;
          _upcomingClass = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 48),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '欢迎来到大贝壳NEXT',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '北京科技大学校园助手',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 48),
            _buildFeatureGrid(),
            const SizedBox(height: 32),
            _buildNetFeatureGrid(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrowScreen = constraints.maxWidth < 600;
        final theme = Theme.of(context);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '教务管理',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isNarrowScreen) ...[
                _buildNarrowLayout(),
              ] else ...[
                _buildWideLayout(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNarrowLayout() {
    final examMode = _getExamModeEnabled();

    if (examMode) {
      final examCards = <_FeatureCardConfig>[
        _FeatureCardConfig(
          title: '选课',
          description: '查看和管理课程',
          icon: Icons.school,
          color: (c) => Theme.of(c).colorScheme.primary,
          route: '/courses/selection',
        ),
        _FeatureCardConfig(
          title: '课表',
          description: '查看每周课程安排',
          icon: Icons.calendar_today,
          color: (c) => Theme.of(c).colorScheme.primary,
          route: '/courses/curriculum',
        ),
        _FeatureCardConfig(
          title: '成绩',
          description: '查看考试成绩',
          icon: Icons.assessment,
          color: (c) => Theme.of(c).colorScheme.primary,
          route: '/courses/grade',
        ),
      ];
      return Column(
        children: [
          _buildExamCard(context, isWideScreen: false),
          const SizedBox(height: 8),
          SizedBox(height: 100, child: _buildAccountCard(context)),
          ...examCards.map((card) {
            return Column(
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: _buildFeatureCard(
                    context,
                    card.title,
                    card.description,
                    card.icon,
                    card.color,
                    () {
                      Haptics.selection();
                      pushPathGuarded(context, card.route);
                    },
                  ),
                ),
              ],
            );
          }),
        ],
      );
    }

    return Column(
      children: [
        _buildCurriculumCard(context, isWideScreen: false),
        const SizedBox(height: 8),
        SizedBox(height: 100, child: _buildAccountCard(context)),
        ..._courseFeatureCards.map((card) {
          return Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: _buildFeatureCard(
                  context,
                  card.title,
                  card.description,
                  card.icon,
                  card.color,
                  () {
                    Haptics.selection();
                    pushPathGuarded(context, card.route);
                  },
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildWideLayout() {
    final examMode = _getExamModeEnabled();

    if (examMode) {
      final wideExamCards = [
        _FeatureCardConfig(
          title: '选课', description: '查看和管理课程',
          icon: Icons.school, color: (c) => Theme.of(c).colorScheme.primary,
          route: '/courses/selection',
        ),
        _FeatureCardConfig(
          title: '课表', description: '查看每周课程安排',
          icon: Icons.calendar_today, color: (c) => Theme.of(c).colorScheme.primary,
          route: '/courses/curriculum',
        ),
        _FeatureCardConfig(
          title: '成绩', description: '查看考试成绩',
          icon: Icons.assessment, color: (c) => Theme.of(c).colorScheme.primary,
          route: '/courses/grade',
        ),
      ];
      return Column(
        children: [
          _buildExamCard(context, isWideScreen: true),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: _buildCardRow([
              _buildAccountCard(context),
              wideExamCards[0],
            ]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: _buildCardRow([
              wideExamCards[1],
              wideExamCards[2],
            ]),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildCurriculumCard(context, isWideScreen: true),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: _buildCardRow([
            _buildAccountCard(context),
            _courseFeatureCards[0],
          ]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: _buildCardRow([
            _courseFeatureCards[1],
            _courseFeatureCards[2],
          ]),
        ),
      ],
    );
  }

  Widget _buildCardRow(List<dynamic> items) {
    return Row(
      children: items.asMap().entries.expand((entry) {
        final index = entry.key;
        final item = entry.value;
        return [
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: item is Widget
                ? item
                : _buildFeatureCard(
                    context,
                    item.title,
                    item.description,
                    item.icon,
                    item.color,
                    () {
                      Haptics.selection();
                      pushPathGuarded(context, item.route);
                    },
                  ),
          ),
        ];
      }).toList(),
    );
  }

  Widget _buildCurriculumCard(
    BuildContext context, {
    required bool isWideScreen,
  }) {
    final theme = Theme.of(context);

    return Card.filled(
      shape: _noBorderShape,
      child: InkWell(
        onTap: () {
          Haptics.selection();
          pushPathGuarded(context, '/courses/curriculum');
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.primaryContainer,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _buildCurriculumContent(isWideScreen: isWideScreen),
          ),
        ),
      ),
    );
  }

  Widget _buildCurriculumContent({required bool isWideScreen}) {
    if (isWideScreen) {
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 36, color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '课表',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '查看每周课程安排',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (_ongoingClass != null || _upcomingClass != null) ...[
            const SizedBox(width: 16),
            Container(
              constraints: BoxConstraints(maxWidth: 290),
              child: _buildMultipleClassPreviews(),
            ),
          ],
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 32, color: Theme.of(context).colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '课表',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          if (_ongoingClass != null || _upcomingClass != null) ...[
            const SizedBox(height: 16),
            _buildMultipleClassPreviews(),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              '查看每周课程安排',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      );
    }
  }

  Widget _buildMultipleClassPreviews() {
    final classes = <ClassItem?>[];
    if (_ongoingClass != null) classes.add(_ongoingClass);
    if (_upcomingClass != null) classes.add(_upcomingClass);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(classes.length, (i) {
          final isOngoing = classes[i] == _ongoingClass;
          return Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
            child: _buildSingleClassPreview(classes[i]!, isOngoing),
          );
        }),
      ),
    );
  }

  Widget _buildSingleClassPreview(ClassItem classItem, bool isOngoing) {
    final startTime = classItem.getMinStartTime(
      _curriculumData?.allPeriods ?? [],
    );
    final endTime = classItem.getMaxEndTime(_curriculumData?.allPeriods ?? []);
    String? periodTimeRange = startTime != null && endTime != null
        ? '${startTime.format(context)} - ${endTime.format(context)}'
        : null;

    final textStyle1 = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
      fontWeight: FontWeight.w500,
    );
    final textStyle2 = TextStyle(
      fontSize: 14,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
      fontWeight: FontWeight.bold,
    );
    final textStyle3 = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isOngoing ? '  进行中' : '  接下来', style: textStyle1),
            const SizedBox(height: 4),
            Text(
              '  ${classItem.className.replaceAll('\n', ' ')}',
              style: textStyle2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (periodTimeRange != null)
              Text('  $periodTimeRange', style: textStyle3),
            if (classItem.locationName.isNotEmpty)
              Text(classItem.locationName, style: textStyle3),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(
    BuildContext context, {
    required bool isWideScreen,
  }) {
    final theme = Theme.of(context);

    return Card.filled(
      shape: _noBorderShape,
      child: InkWell(
        onTap: () {
          Haptics.selection();
          pushPathGuarded(context, '/courses/exam');
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.primaryContainer,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _buildExamContent(isWideScreen: isWideScreen),
          ),
        ),
      ),
    );
  }

  Widget _buildExamContent({required bool isWideScreen}) {
    final hasExams = _ongoingExam != null || _upcomingExam != null;

    if (isWideScreen) {
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment, size: 36,
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '考试',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  hasExams ? '查看考试安排' : '暂无考试',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (hasExams) ...[
            const SizedBox(width: 16),
            Container(
              constraints: const BoxConstraints(maxWidth: 290),
              child: _buildExamPreviews(),
            ),
          ],
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.assignment, size: 32,
                  color: Theme.of(context).colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '考试',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          if (hasExams) ...[
            const SizedBox(height: 16),
            _buildExamPreviews(),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              '暂无考试',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      );
    }
  }

  Widget _buildExamPreviews() {
    final exams = <({ExamInfo exam, bool isOngoing})>[];
    if (_ongoingExam != null) exams.add((exam: _ongoingExam!, isOngoing: true));
    if (_upcomingExam != null) exams.add((exam: _upcomingExam!, isOngoing: false));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(exams.length, (i) {
          final entry = exams[i];
          return Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
            child: _buildSingleExamPreview(entry.exam, entry.isOngoing),
          );
        }),
      ),
    );
  }

  Widget _buildSingleExamPreview(ExamInfo exam, bool isOngoing) {
    final textStyle1 = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
      fontWeight: FontWeight.w500,
    );
    final textStyle2 = TextStyle(
      fontSize: 14,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
      fontWeight: FontWeight.bold,
    );
    final textStyle3 = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
    );

    final dateStr = '${exam.examDateDisplay} ${exam.examDayName}';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isOngoing ? '  考试进行中' : '  接下来', style: textStyle1),
            const SizedBox(height: 4),
            Text(
              '  ${exam.courseName.replaceAll('\n', ' ')}',
              style: textStyle2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text('  $dateStr  ${exam.examTime}', style: textStyle3),
            if (exam.examRoom.isNotEmpty)
              Text('  ${exam.examRoom}', style: textStyle3),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color Function(BuildContext) colorFn,
    VoidCallback onTap,
  ) {
    return Card.filled(
      shape: _noBorderShape,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 32, color: colorFn(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetFeatureGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrowScreen = constraints.maxWidth < 600;
        final theme = Theme.of(context);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cottage,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '生活服务',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isNarrowScreen) ...[
                _buildNetNarrowLayout(),
              ] else ...[
                _buildNetWideLayout(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNetNarrowLayout() {
    return Column(
      children: [
        _buildEmptyClassroomCard(context, isWideScreen: false),
        const SizedBox(height: 8),
        ..._netFeatureCards.asMap().entries.expand((entry) {
          final index = entry.key;
          final card = entry.value;
          return [
            if (index > 0) const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: _buildFeatureCard(
                context,
                card.title,
                card.description,
                card.icon,
                card.color,
                () {
                  Haptics.selection();
                  pushPathGuarded(context, card.route);
                },
              ),
            ),
          ];
        }),
      ],
    );
  }

  Widget _buildNetWideLayout() {
    final cards = _netFeatureCards;
    return Column(
      children: [
        _buildEmptyClassroomCard(context, isWideScreen: true),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: _buildCardRow([cards[0], cards[1]]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: _buildCardRow([cards[2], cards[3]]),
        ),
      ],
    );
  }

  Widget _buildEmptyClassroomCard(BuildContext context, {required bool isWideScreen}) {
    final theme = Theme.of(context);
    final iconSize = isWideScreen ? 36.0 : 32.0;
    final iconGap = isWideScreen ? 16.0 : 12.0;
    final titleFontSize = isWideScreen ? 28.0 : 24.0;
    final titleGap = isWideScreen ? 12.0 : 16.0;
    final descFontSize = isWideScreen ? 16.0 : 14.0;

    return Card.filled(
      shape: _noBorderShape,
      child: InkWell(
        onTap: () {
          Haptics.selection();
          pushPathGuarded(context, _emptyClassroomCard.route);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.primaryContainer,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(_emptyClassroomCard.icon,
                              size: iconSize,
                              color: theme.colorScheme.onPrimaryContainer),
                          SizedBox(width: iconGap),
                          Expanded(
                            child: Text(
                              _emptyClassroomCard.title,
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: titleGap),
                      Text(
                        _emptyClassroomCard.description,
                        style: TextStyle(
                          fontSize: descFontSize,
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    return Card.filled(
      shape: _noBorderShape,
      child: InkWell(
        onTap: () {
          Haptics.selection();
          pushPathGuarded(context, '/courses/account');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_circle, size: 32, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '教务账户',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final service = serviceProvider.coursesService;
                  final scheme = Theme.of(context).colorScheme;

                  if (service.isOnline && _userInfo != null) {
                    return Text(
                      '已作为${_userInfo!.userName}登录',
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  } else if (service.isPending) {
                    return Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text('处理中', style: TextStyle(fontSize: 14)),
                      ],
                    );
                  } else if (service.hasError) {
                    return Text(
                      '登录可能已过期',
                      style: TextStyle(fontSize: 14, color: scheme.error),
                    );
                  } else {
                    return Text(
                      '尚未登录教务账户',
                      style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom painter for the upward-pointing arrow

