import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/ui/layout/screen_breakpoints.dart';

void main() {
  group('screenClassOf', () {
    test('599 dp → phone', () {
      expect(screenClassOf(599.0), equals(ScreenClass.phone));
    });

    test('600 dp → tablet', () {
      expect(screenClassOf(600.0), equals(ScreenClass.tablet));
    });

    test('1023 dp → tablet ancho', () {
      expect(screenClassOf(1023.0), equals(ScreenClass.tablet));
    });

    test('1024 dp → tablet ancho máximo', () {
      expect(screenClassOf(1024.0), equals(ScreenClass.tablet));
    });
  });

  group('horizontalMarginOf', () {
    test('phone → 16.0', () {
      expect(horizontalMarginOf(ScreenClass.phone), equals(16.0));
    });

    test('tablet → 24.0', () {
      expect(horizontalMarginOf(ScreenClass.tablet), equals(24.0));
    });
  });

  group('gutterOf', () {
    test('phone → 12.0', () {
      expect(gutterOf(ScreenClass.phone), equals(12.0));
    });

    test('tablet → 16.0', () {
      expect(gutterOf(ScreenClass.tablet), equals(16.0));
    });
  });

  group('kContentMaxWidth', () {
    test('es 640.0', () {
      expect(kContentMaxWidth, equals(640.0));
    });
  });

  group('kTabletBreakpoint', () {
    test('es 600.0', () {
      expect(kTabletBreakpoint, equals(600.0));
    });
  });
}