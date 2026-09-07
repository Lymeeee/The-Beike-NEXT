import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/services/provider.dart';
import '/services/widget_updater.dart';
import '/main.dart';
import '/types/preferences.dart';
import '/utils/haptic.dart';
import '/types/courses.dart';

const _accentPresets = [
  null,
  Color(0xFF005B94), // 北科蓝
  Color(0xFF9BABB8), // 灰蓝
  Color(0xFFA3B0A1), // 鼠尾草绿
  Color(0xFFC2AEA6), // 烟灰粉
  Color(0xFFB4ADBC), // 薰衣草灰
  Color(0xFFBBAFA0), // 暖灰褐
  Color(0xFF9AB5AF), // 雾蓝绿
  Color(0xFFAEA3B9), // 紫藤灰
  Color(0xFFABB09B), // 橄榄灰
  Color(0xFF93AAB5), // 雾霾蓝
  Color(0xFFC59D90), // 陶土粉
];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _noBorderShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  bool _isClearingData = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildThemeModeRow(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildAccentColorPicker(),
          ),
          const SizedBox(height: 24),
          _buildExamModeToggle(),
          const SizedBox(height: 16),
          _buildHolidayToggle(),
          const SizedBox(height: 16),
          _buildHapticToggle(),
          if (_isSummerTerm()) ...[
            const SizedBox(height: 16),
            _buildSummerTermStartDateCard(),
          ],
          if (Platform.isAndroid) ...[
            const SizedBox(height: 16),
            _buildBatteryOptimizationTile(),
          ],
          const SizedBox(height: 24),
          _buildDataSection(),
        ],
      ),
    );
  }

  Widget _buildThemeModeRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('配色方案', style: Theme.of(context).textTheme.bodyLarge),
              Text(
                ThemeManager.currentThemeMode.displayName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(_getThemeIcon(ThemeManager.currentThemeMode)),
          onPressed: () {
            Haptics.selection();
            ThemeManager.updateThemeMode(
              _getNextThemeMode(ThemeManager.currentThemeMode),
            );
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildAccentColorPicker() {
    final currentColor = ThemeManager.currentAccentColor;
    final theme = Theme.of(context);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _accentPresets.map((color) {
        final isSelected =
            (color == null && currentColor == null) ||
            (color != null &&
                currentColor != null &&
                color.toARGB32() == currentColor.toARGB32());

        return GestureDetector(
          onTap: () {
            Haptics.selection();
            ThemeManager.updateAccentColor(color);
            setState(() {});
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: theme.colorScheme.primary, width: 3)
                  : Border.all(
                      color: theme.colorScheme.outlineVariant,
                      width: 1.5,
                    ),
              color: color,
            ),
            child: color == null
                ? Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary)
                : null,
          ),
        );
      }).toList(),
    );
  }

  bool _getExamModeEnabled() {
    final prefs = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    return prefs?.examMode ?? false;
  }

  void _setExamModeEnabled(bool value) {
    final existing = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    final updated = AppSettings(
      themeMode: existing?.themeMode ?? ThemeManager.currentThemeMode,
      accentColorValue:
          existing?.accentColorValue ?? ThemeManager.currentAccentColor?.toARGB32(),
      holidayMode: existing?.holidayMode ?? false,
      hapticFeedbackEnabled: existing?.hapticFeedbackEnabled ?? true,
      examMode: value,
    );
    _serviceProvider.storeService.putPref<AppSettings>(
      'app_settings',
      updated,
    );

    if (value) {
      _serviceProvider.storeService.delConfig('curriculum_data');
      _updateWidgetForExamMode();
    } else {
      WidgetUpdater().updateFromCurriculum(null);
    }
    _serviceProvider.notifySettingsChanged();
    setState(() {});
  }

  void _updateWidgetForExamMode() {
    final cached = _serviceProvider.storeService.getPref<CachedExamList>(
      'cached_exams',
      CachedExamList.fromJson,
    );
    if (cached != null && cached.exams.isNotEmpty) {
      WidgetUpdater().updateExams(cached.exams);
    }
  }

  Widget _buildExamModeToggle() {
    final enabled = _getExamModeEnabled();

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '考试模式',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '清除课表，首页与小组件显示考试信息',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: enabled,
              onChanged: (value) {
                Haptics.selection();
                _setExamModeEnabled(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _getHolidayMode() {
    final prefs = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    return prefs?.holidayMode ?? false;
  }

  void _setHolidayMode(bool value) {
    final existing = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    final updated = AppSettings(
      themeMode: existing?.themeMode ?? ThemeManager.currentThemeMode,
      accentColorValue:
          existing?.accentColorValue ?? ThemeManager.currentAccentColor?.toARGB32(),
      holidayMode: value,
    );
    _serviceProvider.storeService.putPref<AppSettings>(
      'app_settings',
      updated,
    );

    if (value) {
      _serviceProvider.storeService.delConfig('curriculum_data');
      WidgetUpdater().updateHoliday();
    } else {
      WidgetUpdater().updateFromCurriculum(null);
    }
    _serviceProvider.notifySettingsChanged();
    setState(() {});
  }

  Widget _buildHolidayToggle() {
    final enabled = _getHolidayMode();

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '假期模式',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '清除课表，小组件显示假期祝福',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: enabled,
              onChanged: (value) {
                Haptics.selection();
                _setHolidayMode(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _getHapticEnabled() {
    final prefs = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    return prefs?.hapticFeedbackEnabled ?? true;
  }

  void _setHapticEnabled(bool value) {
    final existing = _serviceProvider.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    final updated = AppSettings(
      themeMode: existing?.themeMode ?? ThemeManager.currentThemeMode,
      accentColorValue:
          existing?.accentColorValue ?? ThemeManager.currentAccentColor?.toARGB32(),
      holidayMode: existing?.holidayMode ?? false,
      hapticFeedbackEnabled: value,
    );
    _serviceProvider.storeService.putPref<AppSettings>(
      'app_settings',
      updated,
    );
    Haptics.refresh();
    setState(() {});
  }

  Widget _buildHapticToggle() {
    final enabled = _getHapticEnabled();

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '触感反馈',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '按钮点击和手势操作时提供触感反馈',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: enabled,
              onChanged: (value) {
                Haptics.selection();
                _setHapticEnabled(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _batteryChannel = MethodChannel('com.lyme.beikenext/battery');

  Future<void> _requestBatteryOptimization() async {
    try {
      await _batteryChannel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开设置: $e')),
        );
      }
    }
  }

  Widget _buildBatteryOptimizationTile() {
    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '电池优化',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '关闭电池优化以确保桌面小组件正常刷新',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.tonalIcon(
              onPressed: () {
                Haptics.light();
                _requestBatteryOptimization();
              },
              icon: const Icon(Icons.battery_saver, size: 18),
              label: const Text('设置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '清除所有数据',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'APP出现故障时可尝试',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _isClearingData
                  ? null
                  : () {
                      Haptics.heavy();
                      _clearAllData();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              icon: _isClearingData
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete, size: 18),
              label: const Text('清除'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除应用全部数据吗？包括登录会话、课表数据、缓存和本地设置。此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () {
              Haptics.light();
              Navigator.of(context).pop(false);
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Haptics.medium();
              Navigator.of(context).pop(true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearingData = true);
    try {
      _serviceProvider.storeService.delAllConfig();
      _serviceProvider.storeService.delAllPref();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('应用数据已清除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除数据失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearingData = false);
    }
  }

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system: return Icons.brightness_auto;
      case ThemeMode.light: return Icons.light_mode;
      case ThemeMode.dark: return Icons.dark_mode;
    }
  }

  ThemeMode _getNextThemeMode(ThemeMode current) {
    switch (current) {
      case ThemeMode.system: return ThemeMode.light;
      case ThemeMode.light: return ThemeMode.dark;
      case ThemeMode.dark: return ThemeMode.system;
    }
  }

  bool _isSummerTerm() {
    final curriculumData = _serviceProvider.storeService
        .getConfig<CurriculumIntegratedData>(
            'curriculum_data', CurriculumIntegratedData.fromJson);
    return curriculumData != null && curriculumData.currentTerm.season >= 3;
  }

  String? _getSummerTermStartDate() {
    final data = _serviceProvider.storeService
        .getConfig<CurriculumIntegratedData>(
            'curriculum_data', CurriculumIntegratedData.fromJson);
    final dt = data?.summerTermStartDate;
    if (dt == null) return null;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  void _setSummerTermStartDate(DateTime date) {
    final data = _serviceProvider.storeService
        .getConfig<CurriculumIntegratedData>(
            'curriculum_data', CurriculumIntegratedData.fromJson);
    if (data != null) {
      data.summerTermStartDate = date;
      _serviceProvider.storeService.putConfig<CurriculumIntegratedData>(
          'curriculum_data', data);
      WidgetUpdater().updateFromCurriculum(data);
    }
    _serviceProvider.notifySettingsChanged();
    setState(() {});
  }

  String _formatSummerTermStartDate(String? date) {
    if (date == null) return '未设定';
    final dt = DateTime.tryParse(date);
    if (dt == null) return '未设定';
    return '${dt.year}年${dt.month}月${dt.day}日';
  }

  Future<void> _showSummerTermDatePicker() async {
    final initialDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择小学期起始日期',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (picked != null) {
      _setSummerTermStartDate(picked);
    }
  }

  Widget _buildSummerTermStartDateCard() {
    final date = _getSummerTermStartDate();

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Haptics.selection();
          _showSummerTermDatePicker();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.calendar_month,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '小学期起始日',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatSummerTermStartDate(date),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: date != null
                                  ? Theme.of(context).colorScheme.onSurfaceVariant
                                  : Theme.of(context).colorScheme.error),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
