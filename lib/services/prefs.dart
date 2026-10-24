import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every setting on the Preferences page, saved on the phone.
class Prefs extends ChangeNotifier {
  static late Prefs instance;
  final SharedPreferences _p;
  Prefs._(this._p);

  static Future<void> init() async => instance = Prefs._(await SharedPreferences.getInstance());

  // helpers
  T _get<T>(String k, T def) => (_p.get(k) as T?) ?? def;
  Future<void> _set(String k, Object v) async {
    if (v is bool) await _p.setBool(k, v);
    if (v is int) await _p.setInt(k, v);
    if (v is double) await _p.setDouble(k, v);
    if (v is String) await _p.setString(k, v);
    notifyListeners();
  }

  // General
  int get themeIndex => _get('themeIndex', 0);
  set themeIndex(int v) => _set('themeIndex', v);
  String get bgStyle => _get('bgStyle', 'glow');
  set bgStyle(String v) => _set('bgStyle', v);
  String get themeMode => _get('themeMode', 'light'); // light | dark | system
  set themeMode(String v) => _set('themeMode', v);
  ThemeMode get mode => switch (themeMode) { 'dark' => ThemeMode.dark, 'system' => ThemeMode.system, _ => ThemeMode.light };
  int get startTab => _get('startTab', 0);
  set startTab(int v) => _set('startTab', v);
  String get weekStart => _get('weekStart', 'Saturday');
  set weekStart(String v) => _set('weekStart', v);
  bool get haptics => _get('haptics', true);
  set haptics(bool v) => _set('haptics', v);

  // To-do
  int get defaultPriority => _get('defaultPriority', 5);
  set defaultPriority(int v) => _set('defaultPriority', v);
  bool get showCompleted => _get('showCompleted', true);
  set showCompleted(bool v) => _set('showCompleted', v);
  String get defaultReminder => _get('defaultReminder', 'none'); // none | 1h | 1d
  set defaultReminder(String v) => _set('defaultReminder', v);
  bool get moveDoneToBottom => _get('moveDoneToBottom', true);
  set moveDoneToBottom(bool v) => _set('moveDoneToBottom', v);

  // Projects
  String get defaultCurrency => _get('defaultCurrency', 'USD');
  set defaultCurrency(String v) => _set('defaultCurrency', v);
  String get defaultPlatform => _get('defaultPlatform', 'fiverr');
  set defaultPlatform(String v) => _set('defaultPlatform', v);
  bool get showMoney => _get('showMoney', true);
  set showMoney(bool v) => _set('showMoney', v);

  // Notes
  bool get notesGrid => _get('notesGrid', true);
  set notesGrid(bool v) => _set('notesGrid', v);
  bool get showNotesOnHome => _get('showNotesOnHome', true);
  set showNotesOnHome(bool v) => _set('showNotesOnHome', v);

  // Notifications
  bool get remindersOn => _get('remindersOn', true);
  set remindersOn(bool v) => _set('remindersOn', v);
  bool get dailySummary => _get('dailySummary', false);
  set dailySummary(bool v) => _set('dailySummary', v);

  bool get notificationsOn => _get('notificationsOn', true);
  set notificationsOn(bool v) => _set('notificationsOn', v);
  bool get focusAlerts => _get('focusAlerts', true);
  set focusAlerts(bool v) => _set('focusAlerts', v);
  bool get appNews => _get('appNews', true);
  set appNews(bool v) => _set('appNews', v);
  int get lastReminderScan => _get('lastReminderScan', 0);
  set lastReminderScan(int v) => _p.setInt('lastReminderScan', v); // no rebuild needed

  /// The tab you last had open in each note (opens there next time).
  int noteTab(String id) => _get('noteTab_$id', 0);
  void setNoteTab(String id, int i) => _p.setInt('noteTab_$id', i);

  // Views
  String get projectView => _get('projectView', 'grid'); // grid | list | board
  set projectView(String v) => _set('projectView', v);

  // Focus & sync
  int get focusMinutes => _get('focusMinutes', 25);
  set focusMinutes(int v) => _set('focusMinutes', v);
  bool get syncOnWifiOnly => _get('syncOnWifiOnly', false);
  set syncOnWifiOnly(bool v) => _set('syncOnWifiOnly', v);

  // Updates
  bool get autoUpdateCheck => _get('autoUpdateCheck', true);
  set autoUpdateCheck(bool v) => _set('autoUpdateCheck', v);
  String get skippedVersion => _get('skippedVersion', '');
  set skippedVersion(String v) => _set('skippedVersion', v);
  int get lastUpdateCheck => _get('lastUpdateCheck', 0);
  set lastUpdateCheck(int v) => _set('lastUpdateCheck', v);
  String get lastNotifiedVersion => _get('lastNotifiedVersion', '');
  set lastNotifiedVersion(String v) => _set('lastNotifiedVersion', v);

  // Backups
  bool get driveAuto => _get('driveAuto', false);
  set driveAuto(bool v) => _set('driveAuto', v);
  bool get localAuto => _get('localAuto', true);
  set localAuto(bool v) => _set('localAuto', v);
  String get driveFreq => _get('driveFreq', 'Daily');
  set driveFreq(String v) => _set('driveFreq', v);
  String get localFreq => _get('localFreq', 'Daily');
  set localFreq(String v) => _set('localFreq', v);
  int get lastDrive => _get('lastDrive', 0);
  set lastDrive(int v) => _set('lastDrive', v);
  int get lastLocal => _get('lastLocal', 0);
  set lastLocal(int v) => _set('lastLocal', v);
  int get keepBackups => _get('keepBackups', 10);
  set keepBackups(int v) => _set('keepBackups', v);
}
