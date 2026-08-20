import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appRouteObserverProvider = Provider<RouteObserver<ModalRoute<void>>>((
  ref,
) {
  return RouteObserver<ModalRoute<void>>();
});
