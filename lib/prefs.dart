import 'dart:convert';
import 'dart:io';

abstract class Prefs {
  static final _saveFile = File('prefs.json');
  static final Directory _cwd = Directory.current;
  static String import = _cwd.path;
  static String export = _cwd.path;

  static void resetCWD() {
    Directory.current = _cwd;
  }

  static void changeCWD(String path) {
    Directory.current = Directory(path);
  }

  static Future<void> save() async {
    resetCWD();
    await _saveFile.writeAsString(jsonEncode({
      'import': import,
      'export': export,
    }));
  }

  static Future<void> load() async {
    resetCWD();
    if (await _saveFile.exists()) {
      var json = jsonDecode(await _saveFile.readAsString());
      import = json['import'];
      export = json['export'];
    }
  }
}
