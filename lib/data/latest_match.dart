part of simplescore_web_app;

Map<String, dynamic>? latestMatchResult;

void loadLatestMatchResult() {
  try {
    final jsonString = html.window.localStorage['latest_match_result'];
    if (jsonString == null) return;

    final decoded = jsonDecode(jsonString);
    if (decoded is Map) {
      latestMatchResult = decoded.map((k, v) => MapEntry('$k', v));
    }
  } catch (_) {}
}

void saveLatestMatchResultBestEffort(Map<String, dynamic> data) {
  try {
    latestMatchResult = data;
    html.window.localStorage['latest_match_result'] = jsonEncode(data);
  } catch (_) {}
}
