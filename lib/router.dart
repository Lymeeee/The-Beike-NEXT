// Copyright (c) 2025, Harry Huang

import 'dart:io' show Platform;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'utils/haptic.dart';
import 'pages/index.dart';
import 'pages/courses/selection/index.dart';
import 'pages/courses/curriculum/index.dart';
import 'pages/courses/exam/index.dart';
import 'pages/courses/grade/index.dart';
import 'pages/courses/account/index.dart';
import 'pages/net/dashboard/index.dart';
import 'pages/net/traffic/index.dart';
import 'pages/net/electricity/index.dart';
import 'pages/net/webvpn/index.dart';
import 'pages/more/settings.dart';
import 'pages/more/update.dart';
import 'pages/empty_classroom/index.dart';

class _BottomTab {
  final IconData icon;
  final String label;
  final String rootPath;

  const _BottomTab({
    required this.icon,
    required this.label,
    required this.rootPath,
  });
}

const _bottomTabs = [
  _BottomTab(icon: Icons.home, label: '首页', rootPath: '/'),
  _BottomTab(icon: Icons.more_horiz, label: '更多', rootPath: '/more/settings'),
];

// Tab the user last selected, or the tab of the tab root last shown.
// Sub-pages highlight this tab instead of the one their path belongs to.
int _originTabIndex = 0;

// Slide in from the right when pushed, back out to the right when popped.
Widget _slideTransitionsBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: child,
  );
}

// 250ms sits in M3's medium motion band (250-400ms); easeOutCubic matches
// the app's existing curve. On Android the slide drives the predictive
// back gesture. Other platforms keep their native transitions (e.g.
// Cupertino slide with edge-swipe back on iOS).
RouteType get _slideRouteType {
  if (Platform.isAndroid) {
    return RouteType.custom(
      transitionsBuilder: _slideTransitionsBuilder,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 250),
      enablePredictiveBackGesture: true,
    );
  }
  return RouteType.adaptive();
}

class AppRouter {
  static final router = RootStackRouter.build(
    routes: [
      NamedRouteDef(
        name: 'HomeRoute',
        path: '/',
        type: _slideRouteType,
        builder: (context, data) => MainLayout(child: const HomePage()),
      ),
      NamedRouteDef(
        name: 'CourseAccountRoute',
        path: '/courses/account',
        type: _slideRouteType,
        builder: (context, data) => MainLayout(child: const AccountPage()),
      ),
      NamedRouteDef(
        name: 'CurriculumRoute',
        path: '/courses/curriculum',
        type: _slideRouteType,
        builder: (context, data) => MainLayout(child: const CurriculumPage()),
      ),
      NamedRouteDef(
        name: 'CourseSelectionRoute',
        path: '/courses/selection',
        type: _slideRouteType,
        builder: (context, data) =>
            MainLayout(child: const CourseSelectionPage()),
      ),
      NamedRouteDef(
        name: 'ExamRoute',
        path: '/courses/exam',
        type: _slideRouteType,
        builder: (context, data) => MainLayout(child: const ExamPage()),
      ),
      NamedRouteDef(
        name: 'GradeRoute',
        path: '/courses/grade',
        type: _slideRouteType,
        builder: (context, data) => MainLayout(child: const GradePage()),
      ),
      NamedRouteDef(
        name: 'NetDashboardRoute',
        path: '/net/dashboard',
        type: _slideRouteType,
        builder: (context, data) => MainLayout(child: const NetDashboardPage()),
      ),
      NamedRouteDef(
        name: 'NetTrafficRoute',
        path: '/net/traffic',
        type: _slideRouteType,
        builder: (context, data) => MainLayout(child: const NetTrafficPage()),
      ),
      NamedRouteDef(
        name: 'NetElectricityRoute',
        path: '/net/electricity',
        type: _slideRouteType,
        builder: (context, data) => MainLayout(child: const ElectricityPage()),
      ),
      NamedRouteDef(
        name: 'WebVpnRoute',
        path: '/net/webvpn',
        type: _slideRouteType,
        builder: (context, data) => MainLayout(child: const WebVpnPage()),
      ),
      NamedRouteDef(
        name: 'SettingsRoute',
        path: '/more/settings',
        type: _slideRouteType,
        builder: (context, data) => MainLayout(child: const SettingsPage()),
      ),
      NamedRouteDef(
        name: 'UpdateRoute',
        path: '/more/update',
        type: _slideRouteType,
        builder: (context, data) => MainLayout(child: const UpdatePage()),
      ),
      NamedRouteDef(
        name: 'EmptyClassroomRoute',
        path: '/net/empty-classroom',
        type: _slideRouteType,
        builder: (context, data) =>
            MainLayout(child: const EmptyClassroomPage()),
      ),
    ],
  );
}

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _wasCurrentRoute = false;

  String get _path => context.routeData.path;

  bool get _isTabRoot => _bottomTabs.any((t) => t.rootPath == _path);

  int get _pathTabIndex {
    final path = _path;
    final index = _bottomTabs.indexWhere((t) => t.rootPath == path);
    return index == -1 ? 0 : index;
  }

  bool get _isCurrentRoute {
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  void _onTabSelected(int index) {
    Haptics.selection();
    _originTabIndex = index;

    final router = context.router;
    final targetPath = _bottomTabs[index].rootPath;
    if (router.stack.any((page) => page.routeData.path == targetPath)) {
      router.popUntilRouteWithPath(targetPath);
    } else {
      router.pushPath(targetPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isTabRoot) {
      // When a tab root becomes visible again, sub-pages entered from it
      // should highlight this tab.
      final isCurrent = _isCurrentRoute;
      if (isCurrent && !_wasCurrentRoute) {
        _originTabIndex = _pathTabIndex;
      }
      _wasCurrentRoute = isCurrent;
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _isTabRoot ? _pathTabIndex : _originTabIndex,
        onDestinationSelected: _onTabSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _bottomTabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
