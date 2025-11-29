import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Responsive scaler anchored to a 1080x2400-class device (~411x914 logical dp).
/// Use rW for horizontal sizes, rH for vertical, and rSp for font/icon sizes.
class Responsive {
  final double _scaleW;
  final double _scaleH;
  final double _scaleSp;

  const Responsive._(this._scaleW, this._scaleH, this._scaleSp);

  static Responsive of(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Baseline from ~1080x2400 px device (logical ~411x914 dp)
    const baseW = 411.0;
    const baseH = 914.0;
    final scaleW = size.width / baseW;
    final scaleH = size.height / baseH;
    // Use geometric mean to keep proportions stable for text/icons
    final scaleSp = math.sqrt(scaleW * scaleH);
    return Responsive._(scaleW, scaleH, scaleSp);
  }

  double rW(double value) => value * _scaleW;
  double rH(double value) => value * _scaleH;
  double rSp(double value) => value * _scaleSp;
}