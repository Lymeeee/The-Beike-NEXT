import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import '/types/courses.dart';
import '/types/base.dart';
import '/utils/haptic.dart';
import '/utils/navigation.dart';

String formatCacheTime(BaseDataClass cachedData) {
  final time = cachedData.$lastUpdateTime!;
  final dateString =
      '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  final timeString =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  return '$dateString $timeString';
}

class ChooseCacheCard extends StatelessWidget {
  final CurriculumIntegratedData cachedData;
  final VoidCallback onSubmit;
  final bool useFlexLayout;
  final bool isLoading;

  const ChooseCacheCard({
    super.key,
    required this.cachedData,
    required this.onSubmit,
    this.useFlexLayout = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = cachedData;

    return Card.filled(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: useFlexLayout ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '使用缓存课表',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '直接查看之前缓存的课表',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '缓存时间：${formatCacheTime(cachedData)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.school,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${data.currentTerm.year}学年 第${data.currentTerm.season}学期',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (useFlexLayout) const Spacer(),
            SizedBox(
              height: 36,
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: isLoading ? null : () {
                Haptics.medium();
                onSubmit();
              },
                icon: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Icon(Icons.visibility),
                label: Text(isLoading ? '加载中' : '查看'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChooseLatestCard extends StatefulWidget {
  final bool isLoggedIn;
  final ValueChanged<TermInfo>? onTermSelected;
  final bool useFlexLayout;
  final bool isLoading;
  final Future<List<TermInfo>> Function() getTerms;

  const ChooseLatestCard({
    super.key,
    required this.isLoggedIn,
    required this.getTerms,
    this.onTermSelected,
    this.useFlexLayout = false,
    this.isLoading = false,
  });

  @override
  State<ChooseLatestCard> createState() => _ChooseLatestCardState();
}

class _ChooseLatestCardState extends State<ChooseLatestCard> {
  TermInfo? _selectedTerm;
  List<TermInfo>? _availableTerms;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _loadTerms();
    }
  }

  @override
  void didUpdateWidget(ChooseLatestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When login status changes from false to true, load terms
    if (!oldWidget.isLoggedIn && widget.isLoggedIn) {
      _loadTerms();
    }
  }

  Future<void> _loadTerms() async {
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      final terms = await widget.getTerms();
      if (mounted) {
        setState(() {
          _availableTerms = terms;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _availableTerms = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: widget.useFlexLayout
              ? MainAxisSize.max
              : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.refresh,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '获取最新课表',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '获取并查看指定学期的最新课表',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!widget.isLoggedIn)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.login,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                        size: 24,
                      ),
                      onPressed: () {
                        Haptics.selection();
                        pushPathGuarded(context, '/courses/account');
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '请先登录以获取学期列表',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_availableTerms == null && _errorMessage == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('正在加载学期列表...'),
                  ],
                ),
              )
            else if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Theme.of(context).colorScheme.onErrorContainer, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '加载失败：$_errorMessage',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_availableTerms == null || _availableTerms!.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Theme.of(context).colorScheme.onErrorContainer, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '暂无可用学期',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<TermInfo>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '选择学期',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                initialValue: _selectedTerm,
                isExpanded: true,
                items: _availableTerms!.map((term) {
                  return DropdownMenuItem<TermInfo>(
                    value: term,
                    child: Text('${term.year}学年 第${term.season}学期'),
                  );
                }).toList(),
                onChanged: (TermInfo? value) {
                  setState(() {
                    _selectedTerm = value;
                  });
                },
              ),
            const SizedBox(height: 24),
            if (widget.useFlexLayout) const Spacer(),
            SizedBox(
              height: 36,
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: widget.isLoading
                    ? null
                    : (widget.isLoggedIn &&
                              _selectedTerm != null &&
                              widget.onTermSelected != null
                          ? () {
                              Haptics.medium();
                              widget.onTermSelected!(_selectedTerm!);
                            }
                          : null),
                icon: widget.isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Icon(Icons.visibility),
                label: Text(widget.isLoading ? '加载中' : '查看'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
