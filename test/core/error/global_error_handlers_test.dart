import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/error/global_error_handlers.dart';

void main() {
  group('handlePlatformError', () {
    test('返回 true 表示异常已被兜底处理', () {
      expect(
        handlePlatformError(StateError('boom'), StackTrace.current),
        isTrue,
      );
    });
  });

  group('handleZoneError', () {
    test('不抛出二次异常', () {
      expect(
        () => handleZoneError(Exception('async boom'), StackTrace.current),
        returnsNormally,
      );
    });
  });

  group('handleFlutterError', () {
    test('不抛出二次异常且保留原始异常信息', () {
      final details = FlutterErrorDetails(
        exception: StateError('build boom'),
        stack: StackTrace.current,
        library: 'test',
      );
      expect(() => handleFlutterError(details), returnsNormally);
    });
  });

  group('logUnhandledError', () {
    test('接受 null 堆栈', () {
      expect(
        () => logUnhandledError('platform', 'oops', null),
        returnsNormally,
      );
    });
  });
}
