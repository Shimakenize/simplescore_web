// ===== main.dart (SPLIT-ONLY, NO-LOGIC-CHANGES) =====
library simplescore_web_app;

import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'dart:js_util' as js_util;

part 'data/my_teams.dart';
part 'data/latest_match.dart';

part 'screens/my_teams_screen.dart';
part 'screens/team_editor_screen.dart';
part 'screens/setup_screen.dart';
part 'screens/match_screen.dart';
part 'screens/result_screen.dart';

void main() {
  loadMyTeamsBestEffort();
  loadLatestMatchResult();
  runApp(const SimpleScoreWebApp());
}

class SimpleScoreWebApp extends StatelessWidget {
  const SimpleScoreWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Score Web',
      theme: ThemeData(useMaterial3: true),
      home: const SetupScreen(),
    );
  }
}
