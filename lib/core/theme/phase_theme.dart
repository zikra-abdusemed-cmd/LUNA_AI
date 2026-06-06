import 'package:flutter/material.dart';
import 'app_theme.dart';

enum CyclePhase { menstrual, follicular, ovulation, luteal, unknown }

extension CyclePhaseExt on CyclePhase {
  Color get color {
    switch (this) {
      case CyclePhase.menstrual:  return AppTheme.menstrual;
      case CyclePhase.follicular: return AppTheme.follicular;
      case CyclePhase.ovulation:  return AppTheme.ovulation;
      case CyclePhase.luteal:     return AppTheme.luteal;
      case CyclePhase.unknown:    return AppTheme.textSub;
    }
  }

  String get name {
    switch (this) {
      case CyclePhase.menstrual:  return 'Menstrual';
      case CyclePhase.follicular: return 'Follicular';
      case CyclePhase.ovulation:  return 'Ovulation';
      case CyclePhase.luteal:     return 'Luteal';
      case CyclePhase.unknown:    return 'Unknown';
    }
  }

  String get emoji {
    switch (this) {
      case CyclePhase.menstrual:  return '🌑';
      case CyclePhase.follicular: return '🌱';
      case CyclePhase.ovulation:  return '🌕';
      case CyclePhase.luteal:     return '🌘';
      case CyclePhase.unknown:    return '✨';
    }
  }

  String get tagline {
    switch (this) {
      case CyclePhase.menstrual:  return 'Rest & Restore';
      case CyclePhase.follicular: return 'Rising Energy';
      case CyclePhase.ovulation:  return 'Peak Power';
      case CyclePhase.luteal:     return 'Wind Down';
      case CyclePhase.unknown:    return 'Track your cycle';
    }
  }

  String get advice {
    switch (this) {
      case CyclePhase.menstrual:
        return 'Your body is working hard. Be gentle with yourself today.';
      case CyclePhase.follicular:
        return 'Energy is rising — great time for new projects and planning.';
      case CyclePhase.ovulation:
        return 'You\'re at peak clarity and communication. Shine today.';
      case CyclePhase.luteal:
        return 'Finish existing work. Avoid taking on too much right now.';
      case CyclePhase.unknown:
        return 'Log your period to unlock personalized phase insights.';
    }
  }

  static CyclePhase fromString(String s) {
    switch (s) {
      case 'menstrual':  return CyclePhase.menstrual;
      case 'follicular': return CyclePhase.follicular;
      case 'ovulation':  return CyclePhase.ovulation;
      case 'luteal':     return CyclePhase.luteal;
      default:           return CyclePhase.unknown;
    }
  }
}