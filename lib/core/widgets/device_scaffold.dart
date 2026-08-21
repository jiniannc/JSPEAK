import 'package:flutter/material.dart';

import '../config/active5_layout.dart';

/// Active 5 화면 여백과 최대 너비를 맞춰 주는 공통 스캐폴드.
class DeviceScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  /// false면 하단 세이프 영역을 비워 플로팅 네비가 본문 위에 겹칠 수 있다.
  final bool safeAreaBottom;

  /// false면 상단 SafeArea 생략 — MainShell 공통 헤더와 함께 쓸 때.
  final bool safeAreaTop;

  /// 키보드 등 하단 inset에 맞춰 body 높이를 줄일지 (Scaffold 기본값 true).
  final bool resizeToAvoidBottomInset;

  const DeviceScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.backgroundColor,
    this.safeAreaBottom = true,
    this.safeAreaTop = true,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = Active5Layout.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      // 탭 루트에서 글래스 네비 아래로 비치게 할 때 transparent 권장.
      backgroundColor: backgroundColor ??
          (safeAreaBottom ? null : Colors.transparent),
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: metrics.isLandscape
                  ? Active5Layout.logicalWidthLandscape
                  : Active5Layout.logicalWidthPortrait,
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}
