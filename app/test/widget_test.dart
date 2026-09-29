import 'package:tradehub_demo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('App shell can be constructed', () {
    const app = TradeHubApp();
    expect(app, isA<StatelessWidget>());
  });
}
