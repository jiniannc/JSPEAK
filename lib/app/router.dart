import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../data/models/scenario.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/dictionary/dictionary_category_screen.dart';
import '../features/dictionary/dictionary_home_screen.dart';
import '../features/learning/learning_home_screen.dart';
import '../features/learning/learning_hub_shell.dart';
import '../features/my_page/my_page_screen.dart';
import '../features/scenarios/scenario_training_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/basic_sentence/basic_sentence_home_screen.dart';
import '../features/basic_sentence/basic_sentence_training_screen.dart';
import '../features/word_swipe/word_swipe_home_screen.dart';
import '../features/word_swipe/word_swipe_training_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// URL 형태의 라우팅을 사용해 나중에 웹으로 확장할 때 경로를 그대로 쓴다.
final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            ShellRoute(
              builder: (context, state, child) =>
                  LearningHubShell(child: child),
              routes: [
                GoRoute(
                  path: '/scenarios',
                  pageBuilder: (context, state) => NoTransitionPage(
                    key: state.pageKey,
                    child: const LearningHomeScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'list',
                      redirect: (context, state) => '/scenarios',
                    ),
                    GoRoute(
                      path: 'sentences',
                      pageBuilder: (context, state) => NoTransitionPage(
                        key: state.pageKey,
                        child: const BasicSentenceHomeScreen(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'play',
                          parentNavigatorKey: rootNavigatorKey,
                          builder: (context, state) {
                            final lang =
                                state.uri.queryParameters['lang'] ?? 'English';
                            final cat =
                                state.uri.queryParameters['category'] ?? '';
                            final sentenceId =
                                state.uri.queryParameters['sentenceId'];
                            return BasicSentenceTrainingScreen(
                              language: lang,
                              category: cat,
                              initialSentenceId: sentenceId,
                            );
                          },
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'swipe',
                      pageBuilder: (context, state) => NoTransitionPage(
                        key: state.pageKey,
                        child: const WordSwipeHomeScreen(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'play',
                          parentNavigatorKey: rootNavigatorKey,
                          builder: (context, state) {
                            final extra = state.extra;
                            if (extra is WordSwipeArgs) {
                              return WordSwipeTrainingScreen(
                                language: extra.language,
                                category: extra.category,
                                reviewOnly: extra.reviewOnly,
                                initialCardIndex: extra.initialCardIndex,
                                initialUnknownWordIds:
                                    extra.initialUnknownWordIds,
                              );
                            }
                            final lang =
                                state.uri.queryParameters['lang'] ?? 'English';
                            final cat =
                                state.uri.queryParameters['category'] ?? '';
                            final review =
                                state.uri.queryParameters['review'] == '1';
                            return WordSwipeTrainingScreen(
                              language: lang,
                              category: cat,
                              reviewOnly: review,
                            );
                          },
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'train/:scenarioId',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) {
                        final scenarioId = state.pathParameters['scenarioId']!;
                        final extra = state.extra;
                        final lineIndex =
                            int.tryParse(state.uri.queryParameters['line'] ?? '') ??
                                0;
                        if (extra is Scenario) {
                          return ScenarioTrainingScreen(
                            scenario: extra,
                            initialLineIndex: lineIndex,
                          );
                        }
                        return _ScenarioTrainingLoader(
                          scenarioId: scenarioId,
                          initialLineIndex: lineIndex,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dictionary',
              builder: (context, state) => const DictionaryHomeScreen(),
              routes: [
                GoRoute(
                  path: 'search',
                  builder: (context, state) => const SearchScreen(),
                ),
                GoRoute(
                  path: 'category',
                  builder: (context, state) {
                    final lang = state.uri.queryParameters['lang'];
                    final cat =
                        state.uri.queryParameters['category'] ?? '';
                    return DictionaryCategoryScreen(
                      category: cat,
                      language: lang,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/my',
              builder: (context, state) => const MyPageScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/dictionary/swipe',
      redirect: (context, state) => '/scenarios/swipe',
    ),
    // 레거시 경로 → 통합 화면으로 리다이렉트
    GoRoute(
      path: '/search',
      redirect: (context, state) => '/dictionary/search',
    ),
    GoRoute(
      path: '/dictionary/language/:lang',
      redirect: (context, state) => '/dictionary',
    ),
    GoRoute(
      path: '/dictionary/language/:lang/category/:cat',
      redirect: (context, state) {
        final lang = state.pathParameters['lang'] ?? '';
        final cat = state.pathParameters['cat'] ?? '';
        return '/dictionary/category'
            '?lang=${Uri.encodeComponent(lang)}'
            '&category=${Uri.encodeComponent(cat)}';
      },
    ),
  ],
);

/// extra 없이 진입한 경우 콘텐츠에서 시나리오를 찾는다.
class _ScenarioTrainingLoader extends ConsumerWidget {
  final String scenarioId;
  final int initialLineIndex;

  const _ScenarioTrainingLoader({
    required this.scenarioId,
    this.initialLineIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);

    return content.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('시나리오 로드 실패: $e')),
      ),
      data: (state) {
        final matches =
            state.bundle.scenarios.where((s) => s.id == scenarioId);
        if (matches.isEmpty) {
          return Scaffold(
            body: Center(child: Text('시나리오를 찾을 수 없습니다: $scenarioId')),
          );
        }
        return ScenarioTrainingScreen(
          scenario: matches.first,
          initialLineIndex: initialLineIndex,
        );
      },
    );
  }
}
