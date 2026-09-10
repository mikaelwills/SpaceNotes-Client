import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  const Preferences({
    this.sidebarStartsCollapsed = false,
    this.chatPanelStartsCollapsed = false,
    this.agentsEnabled = true,
  });

  final bool sidebarStartsCollapsed;
  final bool chatPanelStartsCollapsed;
  final bool agentsEnabled;

  Preferences copyWith({
    bool? sidebarStartsCollapsed,
    bool? chatPanelStartsCollapsed,
    bool? agentsEnabled,
  }) {
    return Preferences(
      sidebarStartsCollapsed:
          sidebarStartsCollapsed ?? this.sidebarStartsCollapsed,
      chatPanelStartsCollapsed:
          chatPanelStartsCollapsed ?? this.chatPanelStartsCollapsed,
      agentsEnabled: agentsEnabled ?? this.agentsEnabled,
    );
  }
}

class PreferencesNotifier extends StateNotifier<Preferences> {
  PreferencesNotifier(super.initial);

  static const _keySidebarCollapsed = 'pref_sidebar_starts_collapsed';
  static const _keyChatPanelCollapsed = 'pref_chat_panel_starts_collapsed';
  static const _keyAgentsEnabled = 'pref_agents_enabled';

  static Future<Preferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Preferences(
      sidebarStartsCollapsed: prefs.getBool(_keySidebarCollapsed) ?? false,
      chatPanelStartsCollapsed: prefs.getBool(_keyChatPanelCollapsed) ?? false,
      agentsEnabled: prefs.getBool(_keyAgentsEnabled) ?? true,
    );
  }

  Future<void> setSidebarStartsCollapsed(bool value) async {
    state = state.copyWith(sidebarStartsCollapsed: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySidebarCollapsed, value);
  }

  Future<void> setChatPanelStartsCollapsed(bool value) async {
    state = state.copyWith(chatPanelStartsCollapsed: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyChatPanelCollapsed, value);
  }

  Future<void> setAgentsEnabled(bool value) async {
    state = state.copyWith(agentsEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAgentsEnabled, value);
  }
}

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, Preferences>(
  (ref) => throw StateError('preferencesProvider must be overridden at startup'),
);

final agentsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(preferencesProvider).agentsEnabled,
);
