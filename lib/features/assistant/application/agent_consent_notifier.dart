import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/assistant_repository.dart';
import 'assistant_dependencies.dart';

/// 服务端当前 Agent 披露版本（后端 CurrentAgentConsentVersion）；读回未带版本时，
/// 授权弹窗展示与本地乐观授权都以它兜底，两处须保持一致。
const agentConsentFallbackVersion = 3;

/// Agent 授权状态；授权版本与当前披露版本比较，决定是否需要重新确认。
class AgentConsentState {
  final bool loading;
  final bool loaded;
  final bool granted;
  final int consentVersion;
  final int currentVersion;

  const AgentConsentState({
    this.loading = false,
    this.loaded = false,
    this.granted = false,
    this.consentVersion = 0,
    this.currentVersion = 0,
  });

  /// 已授权，但授权版本落后于当前披露版本。
  bool get needsUpgrade =>
      loaded &&
      granted &&
      currentVersion > 0 &&
      consentVersion < currentVersion;

  /// 记忆页可写；否则只读。
  bool get canUseMemory => loaded && granted && !needsUpgrade;

  /// 允许发起 Agent run；否则发送前先弹出授权确认。
  bool get canStartRun => loaded && granted && !needsUpgrade;

  AgentConsentState copyWith({
    bool? loading,
    bool? loaded,
    bool? granted,
    int? consentVersion,
    int? currentVersion,
  }) {
    return AgentConsentState(
      loading: loading ?? this.loading,
      loaded: loaded ?? this.loaded,
      granted: granted ?? this.granted,
      consentVersion: consentVersion ?? this.consentVersion,
      currentVersion: currentVersion ?? this.currentVersion,
    );
  }
}

/// 按登录身份加载与修改 Agent 授权；并发的 reload 合并为同一个请求。
class AgentConsentNotifier extends StateNotifier<AgentConsentState> {
  final AssistantDataSource _repository;
  final String _identityKey;
  int _generation = 0;
  Future<void>? _loadFuture;

  AgentConsentNotifier({
    required AssistantDataSource repository,
    String identityKey = 'direct',
  }) : _repository = repository,
       _identityKey = identityKey,
       super(const AgentConsentState());

  /// 首次需要授权信息时加载；已加载则不重复请求。
  Future<void> ensureLoaded() {
    if (_identityKey.isEmpty || state.loaded) return Future<void>.value();
    return reload();
  }

  /// 重新拉取授权；已有在途请求时复用它。
  Future<void> reload() {
    if (_identityKey.isEmpty || !mounted) return Future<void>.value();
    final active = _loadFuture;
    if (active != null) return active;
    late final Future<void> future;
    future = _reloadOnce().whenComplete(() {
      if (identical(_loadFuture, future)) _loadFuture = null;
    });
    _loadFuture = future;
    return future;
  }

  // 单次拉取；接口失败时按未授权处理，避免误放行。
  Future<void> _reloadOnce() async {
    final generation = ++_generation;
    state = state.copyWith(loading: true);
    try {
      final status = await _repository.loadAgentConsent();
      if (!mounted || generation != _generation) return;
      state = AgentConsentState(
        loaded: true,
        granted: status.granted,
        consentVersion: status.consentVersion,
        currentVersion: status.currentVersion,
      );
    } on ApiException {
      if (!mounted || generation != _generation) return;
      state = const AgentConsentState(loaded: true, granted: false);
    }
  }

  /// 授予授权后重载；读回仍未反映时，本地先视为已授权。
  Future<void> grant() async {
    if (_identityKey.isEmpty || !mounted) return;
    await _repository.setAgentConsent(granted: true);
    if (!mounted) return;
    await reload();
    if (mounted && !state.granted) {
      state = state.copyWith(
        granted: true,
        consentVersion: state.currentVersion == 0
            ? agentConsentFallbackVersion
            : state.currentVersion,
      );
    }
  }

  /// 撤销授权后重载；读回仍为已授权时，本地强制置为未授权。
  Future<void> revoke() async {
    if (_identityKey.isEmpty || !mounted) return;
    await _repository.setAgentConsent(granted: false);
    if (!mounted) return;
    await reload();
    if (mounted && state.granted) {
      state = const AgentConsentState(loaded: true);
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}

/// 按登录身份重建；已登录则立即加载。
final agentConsentNotifierProvider =
    StateNotifierProvider<AgentConsentNotifier, AgentConsentState>((ref) {
      final identityKey = ref.watch(assistantUserKeyProvider);
      final notifier = AgentConsentNotifier(
        repository: ref.read(assistantRepositoryProvider),
        identityKey: identityKey,
      );
      if (identityKey.isNotEmpty) unawaited(notifier.ensureLoaded());
      return notifier;
    });
