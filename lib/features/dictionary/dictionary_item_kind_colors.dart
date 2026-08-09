import 'package:flutter/material.dart';

enum DictionaryItemKind { word, sentence }

/// 즐겨찾기·검색 결과 등 단어/문장 UI 색상 통일.
abstract final class DictionaryItemKindColors {
  static const sentenceAccent = Color(0xFF0EA5E9);
  static const sentenceLabel = Color(0xFF0284C7);
  static const wordAccent = Color(0xFF7C3AED);
  static const wordLabel = Color(0xFF6D28D9);

  static Color accent(DictionaryItemKind kind) => switch (kind) {
        DictionaryItemKind.sentence => sentenceAccent,
        DictionaryItemKind.word => wordAccent,
      };

  static Color label(DictionaryItemKind kind) => switch (kind) {
        DictionaryItemKind.sentence => sentenceLabel,
        DictionaryItemKind.word => wordLabel,
      };

  static Color chipBackground(DictionaryItemKind kind) =>
      accent(kind).withValues(alpha: 0.12);

  static Color chipBorder(DictionaryItemKind kind) =>
      accent(kind).withValues(alpha: 0.18);

  static Color categoryText(DictionaryItemKind kind) =>
      label(kind).withValues(alpha: 0.82);
}
