import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tts_providers.dart';
import '../../data/models/vocabulary_entry.dart';

/// 단어 상세 미니 카드 — 애플 사전 스타일 오버레이 팝업 본문.
class WordDefinitionCard extends ConsumerWidget {
  final VocabularyEntry entry;
  final VoidCallback onClose;

  const WordDefinitionCard({
    super.key,
    required this.entry,
    required this.onClose,
  });

  static const _slate900 = Color(0xFF0F172A);
  static const _slate800 = Color(0xFF1E293B);
  static const _slate500 = Color(0xFF64748B);
  static const _tagFill = Color(0xFFE0F2FE);
  static const _tagText = Color(0xFF0369A1);
  static const _infoFill = Color(0xFFF1F5F9);
  static const _infoText = Color(0xFF334155);
  static const _chipFill = Color(0xFFE2E8F0);
  static const _border = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSpeaking = ref.watch(ttsSpeakingProvider);
    final pronunciation = entry.pronunciation?.trim();
    final category = entry.category?.trim();
    final description = entry.description?.trim();
    final synonym = entry.synonym?.trim();
    final showInfoBox =
        (description != null && description.isNotEmpty) ||
        (synonym != null && synonym.isNotEmpty);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _border,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PopupHeader(onClose: onClose),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category != null && category.isNotEmpty) ...[
                    _CategoryTag(label: category),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    entry.term,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _slate900,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                  if (pronunciation != null && pronunciation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      pronunciation,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _slate500,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    entry.meaning,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _slate800,
                      height: 1.4,
                    ),
                  ),
                  if (showInfoBox) ...[
                    const SizedBox(height: 14),
                    _InfoBox(
                      description: description,
                      synonym: synonym,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: isSpeaking
                          ? null
                          : () => ref
                              .read(ttsSpeakingProvider.notifier)
                              .speakWord(
                                word: entry.term,
                                language: entry.language,
                              ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _slate800,
                        disabledBackgroundColor:
                            _slate800.withValues(alpha: 0.45),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSpeaking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '듣기 ▶',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopupHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _PopupHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: onClose,
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: WordDefinitionCard._slate500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  final String label;

  const _CategoryTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: WordDefinitionCard._tagFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: WordDefinitionCard._tagText,
          height: 1.2,
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String? description;
  final String? synonym;

  const _InfoBox({
    this.description,
    this.synonym,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: WordDefinitionCard._infoFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null && description!.isNotEmpty)
            Text(
              description!,
              style: const TextStyle(
                fontSize: 13,
                color: WordDefinitionCard._infoText,
                height: 1.4,
              ),
            ),
          if (synonym != null && synonym!.isNotEmpty) ...[
            if (description != null && description!.isNotEmpty)
              const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '유의어',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: WordDefinitionCard._slate500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final word in synonym!
                          .split(RegExp(r'[,;/|]'))
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty))
                        _SynonymChip(label: word),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SynonymChip extends StatelessWidget {
  final String label;

  const _SynonymChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: WordDefinitionCard._chipFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: WordDefinitionCard._slate800,
          height: 1.2,
        ),
      ),
    );
  }
}
