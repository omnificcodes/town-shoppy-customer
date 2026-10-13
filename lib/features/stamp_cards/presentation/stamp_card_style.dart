import 'package:flutter/material.dart';

/// The six looks a stamp card can have, keyed by the programme's `icon`:
/// an emoji for the stamps and a warm two-colour gradient for the card.
class StampCardStyle {
  const StampCardStyle._({required this.key, required this.label, required this.emoji, required this.colors, required this.ink});

  final String key;
  final String label;
  final String emoji;
  final List<Color> colors;

  /// Text colour that reads on the gradient.
  final Color ink;

  static const coffee = StampCardStyle._(key: 'coffee', label: 'Coffee', emoji: '☕', colors: [Color(0xFF6F4E37), Color(0xFFB08968)], ink: Colors.white);
  static const food = StampCardStyle._(key: 'food', label: 'Food', emoji: '🍔', colors: [Color(0xFFE85D04), Color(0xFFFFB703)], ink: Colors.white);
  static const salon = StampCardStyle._(key: 'salon', label: 'Salon', emoji: '✂️', colors: [Color(0xFFD63384), Color(0xFFFF8FAB)], ink: Colors.white);
  static const bag = StampCardStyle._(key: 'bag', label: 'Shopping', emoji: '🛍️', colors: [Color(0xFF6A0DAD), Color(0xFFB388FF)], ink: Colors.white);
  static const car = StampCardStyle._(key: 'car', label: 'Auto', emoji: '🚗', colors: [Color(0xFF0B5FA5), Color(0xFF4FC3F7)], ink: Colors.white);
  static const star = StampCardStyle._(key: 'star', label: 'Star', emoji: '⭐', colors: [Color(0xFFB8860B), Color(0xFFFFD86B)], ink: Color(0xFF3A2A00));

  static const all = [coffee, food, salon, bag, car, star];

  static StampCardStyle of(String key) => all.firstWhere((s) => s.key == key, orElse: () => coffee);

  LinearGradient get gradient => LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors);

  Color get accent => colors.last;
}
