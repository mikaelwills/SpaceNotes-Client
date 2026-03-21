import 'package:equatable/equatable.dart';

enum BackendType { opencode, claudecode }

abstract class ConfigState extends Equatable {
  const ConfigState();

  @override
  List<Object?> get props => [];
}

class ConfigLoaded extends ConfigState {
  static const int spacetimeDbPort = 5050;
  static const int openCodePort = 5053;
  static const int claudeCodePort = 5054;

  final String serverIp;
  final String? selectedProviderID;
  final String? selectedModelID;
  final String? defaultAgent;
  final BackendType backendType;

  const ConfigLoaded({
    required this.serverIp,
    this.selectedProviderID,
    this.selectedModelID,
    this.defaultAgent,
    this.backendType = BackendType.opencode,
  });

  String get baseUrl => 'http://$serverIp:$openCodePort';
  String get spacetimeDbHost => '$serverIp:$spacetimeDbPort';
  String get claudeCodeWsUrl => 'ws://$serverIp:$claudeCodePort/ws';

  @override
  List<Object?> get props => [serverIp, selectedProviderID, selectedModelID, defaultAgent, backendType];

  ConfigLoaded copyWith({
    String? serverIp,
    String? selectedProviderID,
    String? selectedModelID,
    String? defaultAgent,
    BackendType? backendType,
  }) {
    return ConfigLoaded(
      serverIp: serverIp ?? this.serverIp,
      selectedProviderID: selectedProviderID ?? this.selectedProviderID,
      selectedModelID: selectedModelID ?? this.selectedModelID,
      defaultAgent: defaultAgent ?? this.defaultAgent,
      backendType: backendType ?? this.backendType,
    );
  }
}

class ConfigLoading extends ConfigState {}

class ConfigError extends ConfigState {
  final String message;

  const ConfigError(this.message);

  @override
  List<Object> get props => [message];
}
