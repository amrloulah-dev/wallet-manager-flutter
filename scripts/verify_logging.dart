import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('lib directory not found');
    exit(1);
  }

  bool foundUnguarded = false;
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in dartFiles) {
    final lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Check if line contains debugPrint and is NOT a comment
      if (line.contains('debugPrint') && !line.startsWith('//')) {
        // If the line itself contains if (kDebugMode), it's guarded
        if (line.contains('if (kDebugMode)')) {
          continue;
        }

        // Check if previous line contains if (kDebugMode)
        bool guarded = false;
        if (i > 0) {
          final prevLine = lines[i - 1].trim();
          if (prevLine.contains('if (kDebugMode)')) {
            guarded = true;
          }
        }

        if (!guarded) {
          print('Unguarded debugPrint in ${file.path}:${i + 1}');
          print('  ${lines[i]}');
          foundUnguarded = true;
        }
      }
    }
  }

  if (foundUnguarded) {
    print('\nFound unguarded debugPrint calls!');
    exit(1);
  } else {
    print('All debugPrint calls are guarded (or at least look like it).');
  }
}
