/// ชนิดข้อมูลให้ตรงกับที่ API ส่งมา
library;

enum Category {
  food('FOOD', 'อาหาร'),
  transport('TRANSPORT', 'เดินทาง'),
  housing('HOUSING', 'ที่อยู่อาศัย'),
  utilities('UTILITIES', 'สาธารณูปโภค'),
  health('HEALTH', 'สุขภาพ'),
  entertainment('ENTERTAINMENT', 'บันเทิง'),
  other('OTHER', 'อื่น ๆ');

  const Category(this.wire, this.label);

  /// ค่าที่ใช้คุยกับ API
  final String wire;

  /// ชื่อที่แสดงบนหน้าจอ
  final String label;

  static Category fromWire(String value) => Category.values.firstWhere(
        (c) => c.wire == value,
        orElse: () => Category.other,
      );
}

class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.note,
    required this.spentOn,
  });

  final String id;
  final double amount;
  final Category category;
  final String? note;
  final DateTime spentOn;

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        category: Category.fromWire(j['category'] as String),
        note: j['note'] as String?,
        spentOn: DateTime.parse(j['spentOn'] as String),
      );
}

class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.totalItems,
    required this.totalPages,
  });

  final List<T> items;
  final int page;
  final int totalItems;
  final int totalPages;

  static PagedResult<Expense> expensesFromJson(Map<String, dynamic> j) => PagedResult<Expense>(
        items: (j['items'] as List<dynamic>)
            .map((e) => Expense.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: j['page'] as int,
        totalItems: j['totalItems'] as int,
        totalPages: j['totalPages'] as int,
      );
}

class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.total,
    required this.count,
  });

  final Category category;
  final double total;
  final int count;

  factory CategoryTotal.fromJson(Map<String, dynamic> j) => CategoryTotal(
        category: Category.fromWire(j['category'] as String),
        total: (j['total'] as num).toDouble(),
        count: (j['count'] as num).toInt(),
      );
}

class Summary {
  const Summary({required this.grandTotal, required this.byCategory});

  final double grandTotal;
  final List<CategoryTotal> byCategory;

  static const empty = Summary(grandTotal: 0, byCategory: []);

  factory Summary.fromJson(Map<String, dynamic> j) => Summary(
        grandTotal: (j['grandTotal'] as num).toDouble(),
        byCategory: (j['byCategory'] as List<dynamic>)
            .map((e) => CategoryTotal.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// error ที่ API ส่งกลับมา แยก field error ออกมาให้ใช้ต่อได้
class ApiException implements Exception {
  ApiException(this.status, this.message, [this.fieldErrors = const {}]);

  final int status;
  final String message;
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}
