import 'package:flutter/material.dart';

/// The five looks a shop can give a scratch card. Each is a gradient for
/// the card face, a darker backdrop for the reveal screen, and a foil
/// tint, so a card reads as the shop's choice from the list to the reveal.
class ScratchCardTheme {
  const ScratchCardTheme._({
    required this.key,
    required this.label,
    required this.face,
    required this.backdrop,
    required this.accent,
    required this.emoji,
  });

  final String key;
  final String label;
  final List<Color> face;
  final List<Color> backdrop;
  final Color accent;
  final String emoji;

  static const gold = ScratchCardTheme._(
    key: 'gold',
    label: 'Gold',
    face: [Color(0xFFFFE27A), Color(0xFFF2B01E), Color(0xFFB8860B)],
    backdrop: [Color(0xFF2B1A05), Color(0xFF5A3A0A)],
    accent: Color(0xFFFFD86B),
    emoji: '🏆',
  );
  static const festive = ScratchCardTheme._(
    key: 'festive',
    label: 'Festive',
    face: [Color(0xFFFF4E6A), Color(0xFFFF7A3D), Color(0xFFFFC857)],
    backdrop: [Color(0xFF3A0A1C), Color(0xFF7A1C2E)],
    accent: Color(0xFFFFC857),
    emoji: '🎉',
  );
  static const ocean = ScratchCardTheme._(
    key: 'ocean',
    label: 'Ocean',
    face: [Color(0xFF1FA2FF), Color(0xFF12D8FA), Color(0xFFA6FFCB)],
    backdrop: [Color(0xFF05233A), Color(0xFF0B4F6C)],
    accent: Color(0xFF7CF5FF),
    emoji: '🌊',
  );
  static const berry = ScratchCardTheme._(
    key: 'berry',
    label: 'Berry',
    face: [Color(0xFF8E2DE2), Color(0xFFC13FA8), Color(0xFFFF6FB5)],
    backdrop: [Color(0xFF240A3A), Color(0xFF4A1468)],
    accent: Color(0xFFFF9BD1),
    emoji: '💜',
  );
  static const mint = ScratchCardTheme._(
    key: 'mint',
    label: 'Mint',
    face: [Color(0xFF11998E), Color(0xFF38EF7D), Color(0xFFC6FFDD)],
    backdrop: [Color(0xFF05302B), Color(0xFF0E5E4F)],
    accent: Color(0xFF9DFFC8),
    emoji: '🍀',
  );

  static const all = [gold, festive, ocean, berry, mint];

  static ScratchCardTheme of(String key) => all.firstWhere((t) => t.key == key, orElse: () => gold);

  LinearGradient get faceGradient =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: face);

  LinearGradient get backdropGradient =>
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: backdrop);
}
