import 'package:flutter/material.dart';

/// Returns an icon and accent colour for a given crop name.
class CropStyle {
  final IconData icon;
  final Color color;
  final Color lightColor;

  const CropStyle({
    required this.icon,
    required this.color,
    required this.lightColor,
  });
}

CropStyle cropStyleFor(String? crop) {
  if (crop == null || crop.trim().isEmpty) return _defaultStyle;

  final lower = crop.toLowerCase();

  if (_contains(
      lower, ['wheat', 'barley', 'oat', 'rye', 'triticale', 'grain'])) {
    return const CropStyle(
      icon: Icons.grass,
      color: Color(0xFFC8960C),
      lightColor: Color(0xFFFFF3CD),
    );
  }
  if (_contains(lower, ['corn', 'maize', 'sorghum', 'silage'])) {
    return const CropStyle(
      icon: Icons.energy_savings_leaf,
      color: Color(0xFF2E7D32),
      lightColor: Color(0xFFE8F5E9),
    );
  }
  if (_contains(lower,
      ['soy', 'soybean', 'pulse', 'bean', 'lentil', 'pea', 'chickpea'])) {
    return const CropStyle(
      icon: Icons.spa,
      color: Color(0xFF558B2F),
      lightColor: Color(0xFFF1F8E9),
    );
  }
  if (_contains(lower, ['canola', 'rapeseed', 'sunflower', 'flax', 'oil'])) {
    return const CropStyle(
      icon: Icons.wb_sunny,
      color: Color(0xFFF9A825),
      lightColor: Color(0xFFFFFDE7),
    );
  }
  if (_contains(lower, ['cotton', 'fiber'])) {
    return const CropStyle(
      icon: Icons.cloud,
      color: Color(0xFF90A4AE),
      lightColor: Color(0xFFECEFF1),
    );
  }
  if (_contains(lower, [
    'tomato',
    'potato',
    'vegetable',
    'lettuce',
    'cabbage',
    'onion',
    'carrot'
  ])) {
    return const CropStyle(
      icon: Icons.eco,
      color: Color(0xFFE53935),
      lightColor: Color(0xFFFFEBEE),
    );
  }
  if (_contains(lower, ['rice', 'paddy'])) {
    return const CropStyle(
      icon: Icons.water,
      color: Color(0xFF0288D1),
      lightColor: Color(0xFFE1F5FE),
    );
  }
  if (_contains(
      lower, ['alc', 'alfalfa', 'clover', 'grass', 'pasture', 'forage'])) {
    return const CropStyle(
      icon: Icons.nature,
      color: Color(0xFF388E3C),
      lightColor: Color(0xFFE8F5E9),
    );
  }

  return _defaultStyle;
}

bool _contains(String text, List<String> keywords) =>
    keywords.any((k) => text.contains(k));

const _defaultStyle = CropStyle(
  icon: Icons.energy_savings_leaf,
  color: Color(0xFF2D5A40),
  lightColor: Color(0xFFD4E8DC),
);
