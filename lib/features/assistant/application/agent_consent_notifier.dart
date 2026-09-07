import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/assistant_repository.dart';
import 'assistant_dependencies.dart';

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

  bool get needsUpgrade =>
      loaded &&
      granted &&
      currentVersion > 0 &&
      consentVersion < currentVersion;

  bool get canUseMemoryWatch => loaded && granted && !needsUpgrade;

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

  Future<void> ensureLoaded() {
    if (_identityKey.isEmpty || state.loaded) return Future<void>.value();
    return reload();
  }

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

  Future<void> grant() async {
    if (_identityKey.isEmpty || !mounted) return;
    await _repository.setAgentConsent(granted: true);
    if (!mounted) return;
    await reload();
    if (mounted && !state.granted) {
      state = state.copyWith(
        granted: true,
        consentVersion: state.currentVersion == 0 ? 2 : state.currentVersion,
      );
    }
  }

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
