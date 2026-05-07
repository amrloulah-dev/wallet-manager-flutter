import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  int totalReplacements = 0;

  for (final file in files) {
    String content = file.readAsStringSync();
    bool changed = false;

    // 1. Static Math: (0.XX * 255).round()
    final staticPattern = RegExp(r'\((0\.\d+)\s*\*\s*255\)\.round\(\)');
    content = content.replaceAllMapped(staticPattern, (match) {
      changed = true;
      final val = double.parse(match.group(1)!);
      final calc = (val * 255).round();
      totalReplacements++;
      return calc.toString();
    });

    // 2. AlphaScale Math: (0.XX * alphaScale * 255).round()
    final alphaPattern1 =
        RegExp(r'\((0\.\d+)\s*\*\s*alphaScale\s*\*\s*255\)\.round\(\)');
    content = content.replaceAllMapped(alphaPattern1, (match) {
      changed = true;
      final val = double.parse(match.group(1)!);
      final calc = (val * 255).round();
      totalReplacements++;
      return '($calc * alphaScale).round()';
    });

    // 3. AlphaScale only: (alphaScale * 255).round()
    final alphaPattern2 = RegExp(r'\(\s*alphaScale\s*\*\s*255\s*\)\.round\(\)');
    content = content.replaceAllMapped(alphaPattern2, (match) {
      changed = true;
      totalReplacements++;
      return '(255 * alphaScale).round()';
    });

    if (changed) {
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
  print('Total replacements: $totalReplacements');
}
