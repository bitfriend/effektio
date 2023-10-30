import 'package:acter/router/router.dart';
import 'package:convenient_test_dev/convenient_test_dev.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import './support/appstart.dart';
import 'tests/login.dart';

void main() {
  convenientTestMain(ActerConvenientTestSlot(), () {
    group('login tests', loginTests);
  });
}

class ActerConvenientTestSlot extends ConvenientTestSlot {
  @override
  Future<void> appMain(AppMainExecuteMode mode) async =>
      startFreshTestApp('test-example');

  @override
  BuildContext? getNavContext(ConvenientTest t) => rootNavKey.currentContext;
}
