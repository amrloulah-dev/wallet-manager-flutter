import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/utils/number_parser.dart';

void main() {
  group('NumberParser', () {
    group('toDouble', () {
      test('should return double when value is int', () {
        expect(NumberParser.toDouble(10), 10.0);
      });

      test('should return double when value is double', () {
        expect(NumberParser.toDouble(10.5), 10.5);
      });

      test('should return double when value is numeric string', () {
        expect(NumberParser.toDouble('10.5'), 10.5);
      });

      test('should handle commas in strings', () {
        expect(NumberParser.toDouble('1,000.50'), 1000.50);
      });

      test('should strip non-numeric characters except decimal point', () {
        expect(NumberParser.toDouble('EGP 123.45'), 123.45);
        expect(NumberParser.toDouble('100\$'), 100.0);
        expect(NumberParser.toDouble('Amount: 50.00'), 50.0);
      });

      test('should return default value when value is null', () {
        expect(NumberParser.toDouble(null), 0.0);
        expect(NumberParser.toDouble(null, 1.0), 1.0);
      });

      test('should return default value when value is invalid string', () {
        expect(NumberParser.toDouble('abc'), 0.0);
      });

      test('should return default value when value is unexpected type', () {
        expect(NumberParser.toDouble([]), 0.0);
      });
    });

    group('toInt', () {
      test('should return int when value is int', () {
        expect(NumberParser.toInt(10), 10);
      });

      test('should return int when value is double', () {
        expect(NumberParser.toInt(10.9), 10);
      });

      test('should return int when value is numeric string', () {
        expect(NumberParser.toInt('10'), 10);
      });

      test('should handle commas in strings', () {
        expect(NumberParser.toInt('1,000'), 1000);
      });

      test('should return default value when value is null', () {
        expect(NumberParser.toInt(null), 0);
        expect(NumberParser.toInt(null, 1), 1);
      });

      test('should return default value when value is invalid string', () {
        expect(NumberParser.toInt('abc'), 0);
      });

      test('should return default value when value is unexpected type', () {
        expect(NumberParser.toInt({}), 0);
      });
    });
  });
}
