import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart'
    as legacy;
import 'package:xiaobaihe_app/features/assistant/application/assistant_dependencies.dart'
    as dependencies;
import 'package:xiaobaihe_app/features/assistant/application/agent_consent_notifier.dart'
    as consent;
import 'package:xiaobaihe_app/features/assistant/application/assistant_state.dart'
    as model;

void main() {
  test('legacy imports re-export the same providers and state types', () {
    expect(
      identical(
        legacy.assistantRepositoryProvider,
        dependencies.assistantRepositoryProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        legacy.assistantUserKeyProvider,
        dependencies.assistantUserKeyProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        legacy.agentConsentNotifierProvider,
        consent.agentConsentNotifierProvider,
      ),
      isTrue,
    );
    expect(const legacy.AssistantState(), isA<model.AssistantState>());
  });
}
