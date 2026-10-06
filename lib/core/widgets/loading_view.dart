import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// 居中的加载指示，供页面首屏、异步区块等尚无内容可展示时统一使用。
///
/// 按钮内的小号进度圈不属于此类，仍直接使用 `FCircularProgress(size: .sm)`。
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: FCircularProgress());
  }
}
