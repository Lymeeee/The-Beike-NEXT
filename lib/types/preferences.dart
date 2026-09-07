import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/material.dart';
import 'base.dart';

part 'preferences.g.dart';

enum WeekendDisplayMode {
  always, // 始终显示 (min=7, max=7)
  auto, // 自动显示 (min=5, max=7)
  never, // 从不显示 (min=5, max=5)
}

enum TableSize {
  small, // 中等尺寸 (h=80)
  medium, // 大尺寸 (h=100)
  large, // 超大尺寸 (h=120)
}

enum AnimationMode {
  none, // 无动画
  fade, // 渐变动画
  slide, // 滑动动画
}

extension WeekendDisplayModeExtension on WeekendDisplayMode {
  String get displayName {
    switch (this) {
      case WeekendDisplayMode.always:
        return '始终';
      case WeekendDisplayMode.auto:
        return '自动';
      case WeekendDisplayMode.never:
        return '从不';
    }
  }

  String get description {
    switch (this) {
      case WeekendDisplayMode.always:
        return '始终显示周末';
      case WeekendDisplayMode.auto:
        return '有课时显示周末';
      case WeekendDisplayMode.never:
        return '从不显示周末';
    }
  }
}

extension TableSizeExtension on TableSize {
  String get displayName {
    switch (this) {
      case TableSize.small:
        return '中';
      case TableSize.medium:
        return '大';
      case TableSize.large:
        return '超大';
    }
  }

  double get ratio {
    switch (this) {
      case TableSize.small:
        return 1.0;
      case TableSize.medium:
        return 1.2;
      case TableSize.large:
        return 1.4;
    }
  }
}

extension AnimationModeExtension on AnimationMode {
  String get displayName {
    switch (this) {
      case AnimationMode.none:
        return '无';
      case AnimationMode.fade:
        return '渐变';
      case AnimationMode.slide:
        return '滑动';
    }
  }

  String get description {
    switch (this) {
      case AnimationMode.none:
        return '无动画效果';
      case AnimationMode.fade:
        return '渐变动画效果';
      case AnimationMode.slide:
        return '滑动动画效果';
    }
  }
}

extension ThemeModeExtension on ThemeMode {
  String get displayName {
    switch (this) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '亮色';
      case ThemeMode.dark:
        return '暗色';
    }
  }
}

@JsonSerializable()
class CurriculumSettings extends BaseDataClass {
  WeekendDisplayMode weekendMode;
  TableSize tableSize;
  AnimationMode animationMode;
  bool activated;

  CurriculumSettings({
    required this.weekendMode,
    required this.tableSize,
    required this.animationMode,
    this.activated = true,
  });

  @override
  Map<String, dynamic> getEssentials() => {
    'weekendMode': weekendMode,
    'tableSize': tableSize,
    'animationMode': animationMode,
    'activated': activated,
  };

  static final CurriculumSettings defaultSettings = CurriculumSettings(
    weekendMode: WeekendDisplayMode.auto,
    tableSize: TableSize.small,
    animationMode: AnimationMode.slide,
    activated: true,
  );

  int get minWeekdays {
    switch (weekendMode) {
      case WeekendDisplayMode.always:
        return 7;
      case WeekendDisplayMode.auto:
        return 5;
      case WeekendDisplayMode.never:
        return 5;
    }
  }

  int get maxWeekdays {
    switch (weekendMode) {
      case WeekendDisplayMode.always:
        return 7;
      case WeekendDisplayMode.auto:
        return 7;
      case WeekendDisplayMode.never:
        return 5;
    }
  }

  int calculateDisplayDays(List<int> courseDays) {
    if (courseDays.isEmpty) {
      return minWeekdays;
    }
    final maxCourseDay = courseDays.reduce((a, b) => a > b ? a : b);
    final requiredDays = maxCourseDay.clamp(minWeekdays, maxWeekdays);
    return requiredDays;
  }

  factory CurriculumSettings.fromJson(Map<String, dynamic> json) =>
      _$CurriculumSettingsFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CurriculumSettingsToJson(this);
}

@JsonSerializable()
class AppSettings extends BaseDataClass {
  ThemeMode themeMode;
  @JsonKey(name: 'accentColor')
  int? accentColorValue;
  bool holidayMode;
  bool hapticFeedbackEnabled;
  bool examMode;

  AppSettings({
    required this.themeMode,
    this.accentColorValue,
    this.holidayMode = false,
    this.hapticFeedbackEnabled = true,
    this.examMode = false,
  });

  Color? get accentColor =>
      accentColorValue != null ? Color(accentColorValue!) : null;

  @override
  Map<String, dynamic> getEssentials() => {
    'themeMode': themeMode,
    'accentColor': accentColorValue,
    'holidayMode': holidayMode,
    'hapticFeedbackEnabled': hapticFeedbackEnabled,
    'examMode': examMode,
  };

  static final AppSettings defaultSettings = AppSettings(
    themeMode: ThemeMode.system,
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);
}
