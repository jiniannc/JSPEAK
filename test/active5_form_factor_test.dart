import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jspeak/core/config/active5_layout.dart';

void main() {
  test('Active 5 가로·세로 논리 해상도는 태블릿 프로필', () {
    expect(
      Active5FormFactor.fromSize(const Size(960, 600)),
      Active5FormFactor.tabletLandscape,
    );
    expect(
      Active5FormFactor.fromSize(const Size(600, 960)),
      Active5FormFactor.tabletPortrait,
    );
  });

  test('일반 스마트폰 폭은 phone 프로필', () {
    expect(
      Active5FormFactor.fromSize(const Size(390, 844)),
      Active5FormFactor.phone,
    );
  });
}
