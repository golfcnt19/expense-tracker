import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// ที่อยู่ของ API
///
/// ตั้งตอน build ได้ด้วย  --dart-define=API_BASE=https://...
/// ค่าเริ่มต้นชี้ localhost สำหรับตอนพัฒนา
const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:8080',
);

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class ExpenseApi {
  ExpenseApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$apiBase$path').replace(queryParameters: query);

  /// แปลง response ที่ไม่ใช่ 2xx เป็น ApiException พร้อม field error
  Never _fail(http.Response r) {
    var message = 'คำขอล้มเหลว (${r.statusCode})';
    var fields = <String, String>{};
    try {
      final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      message = body['message'] as String? ?? message;
      final fe = body['fieldErrors'];
      if (fe is Map) {
        fields = fe.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } on FormatException {
      // body ไม่ใช่ JSON — ใช้ข้อความตั้งต้น
    }
    throw ApiException(r.statusCode, message, fields);
  }

  Map<String, dynamic> _json(http.Response r) =>
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;

  Future<PagedResult<Expense>> list({
    required DateTime from,
    required DateTime to,
    Category? category,
    int page = 0,
    int size = 20,
  }) async {
    final q = {
      'from': _isoDate(from),
      'to': _isoDate(to),
      'page': '$page',
      'size': '$size',
      if (category != null) 'category': category.wire,
    };
    final r = await _client.get(_uri('/api/expenses', q));
    if (r.statusCode != 200) _fail(r);
    return PagedResult.expensesFromJson(_json(r));
  }

  Future<Summary> summary({required DateTime from, required DateTime to}) async {
    final r = await _client.get(
      _uri('/api/expenses/summary', {'from': _isoDate(from), 'to': _isoDate(to)}),
    );
    if (r.statusCode != 200) _fail(r);
    return Summary.fromJson(_json(r));
  }

  Future<Expense> create({
    required double amount,
    required Category category,
    required DateTime spentOn,
    String? note,
  }) async {
    final r = await _client.post(
      _uri('/api/expenses'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount,
        'category': category.wire,
        'spentOn': _isoDate(spentOn),
        if (note != null && note.isNotEmpty) 'note': note,
      }),
    );
    if (r.statusCode != 201) _fail(r);
    return Expense.fromJson(_json(r));
  }

  Future<void> delete(String id) async {
    final r = await _client.delete(_uri('/api/expenses/$id'));
    if (r.statusCode != 204) _fail(r);
  }

  void close() => _client.close();
}
