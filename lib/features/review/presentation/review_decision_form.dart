import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section.dart';
import '../../ads/application/ads_providers.dart';

typedef ReviewDecisionSubmit = Future<bool> Function({
  required String verdict,
  required List<String> policyCodes,
  String note,
  bool nominateSeed,
});

/// 结论表单：拒绝时必须多选政策码，并展示政策定义（FX-111）。
class ReviewDecisionForm extends StatefulWidget {
  final AdPolicyCatalog policies;
  final bool busy;
  final ReviewDecisionSubmit onSubmit;

  const ReviewDecisionForm({
    super.key,
    required this.policies,
    required this.busy,
    required this.onSubmit,
  });

  @override
  State<ReviewDecisionForm> createState() => _ReviewDecisionFormState();
}

class _ReviewDecisionFormState extends State<ReviewDecisionForm> {
  String _verdict = 'approve';
  final Set<String> _codes = {};
  final _note = TextEditingController();
  bool _nominateSeed = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !widget.busy && (_verdict == 'approve' || _codes.isNotEmpty);

  Future<void> _submit() async {
    await widget.onSubmit(
      verdict: _verdict,
      policyCodes: _codes.toList(),
      note: _note.text,
      nominateSeed: _nominateSeed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final reject = _verdict == 'reject';
    return AppSection(
      title: '审核结论',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FButton(
                  key: const Key('review-verdict-approve'),
                  variant: reject
                      ? FButtonVariant.outline
                      : FButtonVariant.primary,
                  prefix: const Icon(FLucideIcons.circleCheck),
                  onPress: () => setState(() => _verdict = 'approve'),
                  child: Text(reject ? '通过' : '通过（已选）'),
                ),
              ),
              const SizedBox(width: AppTheme.space2),
              Expanded(
                child: FButton(
                  key: const Key('review-verdict-reject'),
                  variant: reject
                      ? FButtonVariant.destructive
                      : FButtonVariant.outline,
                  prefix: const Icon(FLucideIcons.circleX),
                  onPress: () => setState(() => _verdict = 'reject'),
                  child: Text(reject ? '拒绝（已选）' : '拒绝'),
                ),
              ),
            ],
          ),
          if (reject) ...[
            const SizedBox(height: AppTheme.space3),
            Text(
              '选择违反的政策（至少一项）',
              style: theme.typography.body.sm.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.space2),
            for (final policy in widget.policies.codes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space2),
                child: FCheckbox(
                  key: Key('review-code-${policy.code}'),
                  value: _codes.contains(policy.code),
                  label: Text(widget.policies.titleOf(policy.code)),
                  description: Text(
                    policy.category.isEmpty
                        ? policy.code
                        : '${policy.code} · ${policy.category}',
                  ),
                  onChange: (checked) => setState(() {
                    if (checked) {
                      _codes.add(policy.code);
                    } else {
                      _codes.remove(policy.code);
                    }
                  }),
                ),
              ),
            FCheckbox(
              key: const Key('review-nominate-seed'),
              value: _nominateSeed,
              label: const Text('提名为相似违规种子'),
              description: const Text('需另一名审核员确认后才会生效'),
              onChange: (checked) => setState(() => _nominateSeed = checked),
            ),
          ],
          const SizedBox(height: AppTheme.space3),
          FTextField(
            control: FTextFieldControl.managed(controller: _note),
            label: const Text('备注（可选）'),
            maxLines: 3,
            maxLength: 500,
          ),
          if (widget.policies.demo) ...[
            const SizedBox(height: AppTheme.space2),
            Text(
              '政策码与市场为演示配置'
              '${widget.policies.policyVersion.isEmpty ? '' : '（${widget.policies.policyVersion}）'}',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.space3),
          FButton(
            key: const Key('review-submit'),
            onPress: _canSubmit ? _submit : null,
            child: Text(widget.busy ? '提交中…' : '提交结论'),
          ),
        ],
      ),
    );
  }
}
