part of simplescore_web_app;

// ===============================
// Time Format Utils
// ===============================

String formatSeconds(int totalSeconds) {
  if (totalSeconds < 0) totalSeconds = 0;

  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;

  final m = minutes.toString().padLeft(2, '0');
  final s = seconds.toString().padLeft(2, '0');

  return '$m:$s';
}

String formatDuration(Duration d) {
  final totalSeconds = d.inSeconds;
  return formatSeconds(totalSeconds);
}
