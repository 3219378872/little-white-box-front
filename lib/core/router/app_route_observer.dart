import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 挂在应用路由上的共享观察者，页面通过 [RouteAware] 订阅，
/// 在上层页面返回时刷新自身数据（如个人主页的帖子列表）。
final appRouteObserverProvider = Provider<RouteObserver<ModalRoute<void>>>((
  ref,
) {
  return RouteObserver<ModalRoute<void>>();
});
