import 'dart:convert';

import 'package:expense_mobile/api.dart';
import 'package:expense_mobile/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Category', () {
    test('แปลงค่าจาก API เป็น enum ได้', () {
      expect(Category.fromWire('FOOD'), Category.food);
      expect(Category.fromWire('ENTERTAINMENT'), Category.entertainment);
    });

    test('ค่าที่ไม่รู้จักตกไปที่ OTHER แทนที่จะพัง', () {
      // ถ้า API เพิ่มหมวดใหม่ แอปเวอร์ชันเก่าต้องไม่ crash
      expect(Category.fromWire('CRYPTO'), Category.other);
    });
  });

  group('Expense.fromJson', () {
    test('อ่านฟิลด์ครบและแปลงชนิดถูก', () {
      final e = Expense.fromJson({
        'id': 'a1b2',
        'amount': 250.5,
        'category': 'FOOD',
        'note': 'lunch',
        'spentOn': '2026-08-25',
      });

      expect(e.id, 'a1b2');
      expect(e.amount, 250.5);
      expect(e.category, Category.food);
      expect(e.note, 'lunch');
      expect(e.spentOn, DateTime(2026, 8, 25));
    });

    test('amount ที่มาเป็นจำนวนเต็มถูกแปลงเป็น double', () {
      // JSON ส่ง 100 มาเป็น int ไม่ใช่ 100.0
      final e = Expense.fromJson({
        'id': 'x',
        'amount': 100,
        'category': 'OTHER',
        'note': null,
        'spentOn': '2026-01-01',
      });

      expect(e.amount, 100.0);
      expect(e.note, isNull);
    });
  });

  group('ExpenseApi', () {
    test('list ส่ง query parameter ครบและอ่านผลลัพธ์ได้', () async {
      late Uri captured;
      final api = ExpenseApi(
        client: MockClient((req) async {
          captured = req.url;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'i1',
                  'amount': 10,
                  'category': 'FOOD',
                  'note': null,
                  'spentOn': '2026-08-01',
                }
              ],
              'page': 0,
              'size': 20,
              'totalItems': 1,
              'totalPages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await api.list(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
        category: Category.food,
      );

      expect(captured.queryParameters['from'], '2026-08-01');
      expect(captured.queryParameters['to'], '2026-08-31');
      expect(captured.queryParameters['category'], 'FOOD');
      expect(result.totalItems, 1);
      expect(result.items.single.category, Category.food);
    });

    test('ไม่ส่ง category ไปเมื่อไม่ได้กรอง', () async {
      late Uri captured;
      final api = ExpenseApi(
        client: MockClient((req) async {
          captured = req.url;
          return http.Response(
            jsonEncode({
              'items': [],
              'page': 0,
              'size': 20,
              'totalItems': 0,
              'totalPages': 0,
            }),
            200,
          );
        }),
      );

      await api.list(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 2));

      expect(captured.queryParameters.containsKey('category'), isFalse);
    });

    test('400 พร้อม fieldErrors ถูกแปลงเป็น ApiException ที่อ่านรายฟิลด์ได้', () async {
      final api = ExpenseApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'status': 400,
                'error': 'Validation Failed',
                'message': 'Request body failed validation',
                'fieldErrors': {'amount': 'amount must be greater than 0'},
              }),
              400,
            )),
      );

      expect(
        () => api.create(
          amount: -1,
          category: Category.food,
          spentOn: DateTime(2026, 8, 25),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.fieldErrors['amount'], 'fieldErrors.amount',
                  'amount must be greater than 0'),
        ),
      );
    });

    test('update ยิง PUT ไปที่ id ที่ถูกต้องพร้อม body ครบ', () async {
      late http.Request captured;
      final api = ExpenseApi(
        client: MockClient((req) async {
          captured = req;
          return http.Response(
            jsonEncode({
              'id': 'abc-123',
              'amount': 175.25,
              'category': 'HEALTH',
              'note': 'clinic',
              'spentOn': '2026-08-25',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final updated = await api.update(
        'abc-123',
        amount: 175.25,
        category: Category.health,
        spentOn: DateTime(2026, 8, 25),
        note: 'clinic',
      );

      expect(captured.method, 'PUT');
      expect(captured.url.path, endsWith('/api/expenses/abc-123'));

      final sent = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(sent['amount'], 175.25);
      expect(sent['category'], 'HEALTH');
      expect(sent['spentOn'], '2026-08-25');
      expect(sent['note'], 'clinic');

      expect(updated.category, Category.health);
      expect(updated.amount, 175.25);
    });

    test('update ที่ note ว่างไม่ส่งคีย์ note ไปเลย', () async {
      late http.Request captured;
      final api = ExpenseApi(
        client: MockClient((req) async {
          captured = req;
          return http.Response(
            jsonEncode({
              'id': 'x',
              'amount': 10,
              'category': 'OTHER',
              'note': null,
              'spentOn': '2026-08-25',
            }),
            200,
          );
        }),
      );

      await api.update(
        'x',
        amount: 10,
        category: Category.other,
        spentOn: DateTime(2026, 8, 25),
        note: '',
      );

      expect(jsonDecode(captured.body), isNot(contains('note')));
    });

    test('update ที่ไม่เจอ id คืน ApiException 404', () async {
      final api = ExpenseApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'status': 404,
                'error': 'Not Found',
                'message': 'Expense not found',
              }),
              404,
            )),
      );

      expect(
        () => api.update(
          'missing',
          amount: 1,
          category: Category.food,
          spentOn: DateTime(2026, 8, 25),
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('body ที่ไม่ใช่ JSON ยังคืน ApiException ไม่ใช่ FormatException', () async {
      final api = ExpenseApi(
        client: MockClient((_) async => http.Response('<html>502</html>', 502)),
      );

      expect(
        () => api.summary(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 2)),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 502)),
      );
    });
  });

  group('Summary', () {
    test('รวมยอดและหมวดจาก JSON', () {
      final s = Summary.fromJson({
        'from': '2026-08-01',
        'to': '2026-08-31',
        'grandTotal': 351.0,
        'byCategory': [
          {'category': 'FOOD', 'total': 301.0, 'count': 2},
          {'category': 'TRANSPORT', 'total': 50.0, 'count': 1},
        ],
      });

      expect(s.grandTotal, 351.0);
      expect(s.byCategory, hasLength(2));
      expect(s.byCategory.first.category, Category.food);
      expect(s.byCategory.first.count, 2);
    });
  });
}
