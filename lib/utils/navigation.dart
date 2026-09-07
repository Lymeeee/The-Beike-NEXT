// Copyright (c) 2025, Harry Huang

import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

/// Pushes [path] unless it is already the top route, preventing duplicate
/// routes when a tappable card is tapped twice in quick succession.
void pushPathGuarded(BuildContext context, String path) {
  final router = context.router;
  if (router.topRoute.path == path) return;
  router.pushPath(path);
}
