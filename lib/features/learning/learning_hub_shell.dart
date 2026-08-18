import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/learning_hub_language_provider.dart';
import '../../core/theme/animated_language_scope.dart';
import '../../core/widgets/device_scaffold.dart';
import '../shell/main_shell_tab_header.dart';
import 'widgets/learning_hub_edge_back.dart';

/// `/scenarios` 하위 허브·모드 홈 공통 셸.
/// 헤더·배경은 MainShell 공통 헤더/배경(오버레이)이 그리고, 여기서는
/// 뒤로가기 엣지 제스처, 본문 padding, 언어 팔레트 제공만 담당한다.
class LearningHubShell extends ConsumerWidget {
  final Widget child;

  const LearningHubShell({super.key, required this.child});

  static LearningHubHeaderConfig configForLocation(String location) {
    if (location.startsWith('/scenarios/sentences')) {
      return const LearningHubHeaderConfig(id: 'basic_sentence');
    }
    if (location.startsWith('/scenarios/swipe')) {
      return const LearningHubHeaderConfig(id: 'word_swipe');
    }
    return const LearningHubHeaderConfig(id: 'hub');
  }

  static bool isSubModeLocation(String location) {
    final uri = Uri.tryParse(location);
    final path = uri?.path ?? location;
    return path != '/scenarios' && path.startsWith('/scenarios/');
  }

  void _goHub(BuildContext context) => context.go('/scenarios');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final isSubMode = isSubModeLocation(location);
    final language = ref.watch(learningHubLanguageProvider);

    return PopScope(
      canPop: !isSubMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isSubMode) {
          _goHub(context);
        }
      },
      child: DeviceScaffold(
        safeAreaBottom: false,
        safeAreaTop: false,
        backgroundColor: Colors.transparent,
        body: LearningHubEdgeBack(
          enabled: isSubMode,
          onBack: () => _goHub(context),
          child: MainShellTabBody(
            child: AnimatedLanguageScope(
              language: language,
              builder: (context, palette) => child,
            ),
          ),
        ),
      ),
    );
  }
}

class LearningHubHeaderConfig {
  final String id;

  const LearningHubHeaderConfig({required this.id});
}
