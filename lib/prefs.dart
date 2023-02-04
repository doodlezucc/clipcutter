import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

abstract class Prefs {
  static final _saveFile = File('prefs.json');
  static final Directory _cwd = Directory.current;
  static bool _lockImport = false;
  static bool _lockExport = false;

  static String _import = _cwd.path;
  static String get import => _import;
  static set import(String s) {
    if (_lockImport) return;
    _import = s;
    save();
  }

  static String _export = _cwd.path;
  static String get export => _export;
  static set export(String s) {
    if (_lockExport) return;
    _export = s;
    save();
  }

  static void resetCWD() {
    Directory.current = _cwd;
  }

  static void changeCWD(String path) {
    Directory.current = Directory(path);
  }

  static Future<void> save() async {
    resetCWD();
    await _saveFile.writeAsString(jsonEncode({
      'import': _import,
      'export': _export,
      'lockImport': _lockImport,
      'lockExport': _lockExport,
    }));
    print('Saved');
  }

  static Future<void> load() async {
    resetCWD();
    if (await _saveFile.exists()) {
      var json = jsonDecode(await _saveFile.readAsString());
      _import = json['import'];
      _export = json['export'];
      _lockImport = json['lockImport'] ?? false;
      _lockExport = json['lockExport'] ?? false;
    }
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text('Default Directories'),
            tiles: <SettingsTile>[
              DefaultDirectory(
                'Import',
                icon: Icons.folder,
                lock: Prefs._lockImport,
                path: Prefs._import,
                onToggle: (v) => setState(() => Prefs._lockImport = v),
                onChange: (s) => setState(() {
                  Prefs._import = s;
                  Prefs._lockImport = true;
                }),
              ),
              DefaultDirectory(
                'Export',
                icon: Icons.movie_creation,
                lock: Prefs._lockExport,
                path: Prefs._export,
                onToggle: (v) => setState(() => Prefs._lockExport = v),
                onChange: (s) => setState(() {
                  Prefs._export = s;
                  Prefs._lockExport = true;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DefaultDirectory extends SettingsTile {
  DefaultDirectory(
    String name, {
    Key? key,
    required IconData icon,
    required bool lock,
    required String path,
    required void Function(bool) onToggle,
    required void Function(String s) onChange,
  }) : super.switchTile(
          initialValue: lock,
          onToggle: (v) {
            onToggle(v);
            Prefs.save();
          },
          activeSwitchColor: Colors.blue,
          title: Text('Lock $name Directory'),
          leading: Icon(icon),
          description: Text(path),
          onPressed: (ctx) => _pickDirectory(name, path, onChange),
          key: key,
        );

  static void _pickDirectory(
    String name,
    String path,
    void Function(String) onSuccess,
  ) async {
    var s = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pick $name Directory',
      initialDirectory: path,
      lockParentWindow: true,
    );
    if (s != null) {
      onSuccess(s);
      Prefs.save();
    }
  }
}
