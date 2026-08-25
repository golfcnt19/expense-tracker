import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api.dart';
import 'models.dart';

void main() => runApp(const ExpenseApp());

const _bg = Color(0xFF070B0D);
const _surface = Color(0xFF0C1214);
const _raised = Color(0xFF121A1D);
const _line = Color(0xFF1A2427);
const _text = Color(0xFFE6EDEA);
const _muted = Color(0xFF8A9A97);
const _acc = Color(0xFF4FD1C5);
const _warn = Color(0xFFF0A868);
const _bad = Color(0xFFF97066);

final _money = NumberFormat('#,##0.00', 'th_TH');
final _day = DateFormat('yyyy-MM-dd');

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _acc,
      brightness: Brightness.dark,
    ).copyWith(surface: _bg, primary: _acc, error: _bad);

    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: _bg,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: _raised,
          border: OutlineInputBorder(borderSide: BorderSide(color: _line)),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _acc),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = ExpenseApi();

  DateTime _to = DateTime.now();
  late DateTime _from = _to.subtract(const Duration(days: 30));
  Category? _filter;

  PagedResult<Expense>? _page;
  Summary _summary = Summary.empty;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // ยิงสองคำขอพร้อมกัน ไม่ต้องรอทีละอัน
      final results = await Future.wait([
        _api.list(from: _from, to: _to, category: _filter, size: 50),
        _api.summary(from: _from, to: _to),
      ]);
      if (!mounted) return;
      setState(() {
        _page = results[0] as PagedResult<Expense>;
        _summary = results[1] as Summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'เชื่อมต่อ API ไม่ได้ ($apiBase)';
        _loading = false;
      });
    }
  }

  /// เปิดฟอร์มเดียวกันทั้งเพิ่มและแก้ไข
  /// ส่ง existing มา = โหมดแก้ไข ไม่ส่ง = โหมดเพิ่ม
  Future<void> _openSheet({Expense? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      builder: (_) => ExpenseSheet(api: _api, existing: existing),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('ลบรายการ?', style: TextStyle(color: _text)),
        content: Text(
          '${_money.format(e.amount)} บาท · ${e.category.label}',
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ', style: TextStyle(color: _bad)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.delete(e.id);
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบไม่สำเร็จ: $err'), backgroundColor: _bad),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'expense.tracker',
          style: TextStyle(
            color: _text,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _line),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: _muted),
            tooltip: 'โหลดใหม่',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        backgroundColor: _acc,
        foregroundColor: const Color(0xFF04100E),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่ม'),
      ),
      // จำกัดความกว้างไว้ที่ 560 แล้วจัดกลางจอ
      //
      // นี่คือ mobile client เปิดบนเดสก์ท็อปแล้วปล่อยให้ยืดเต็ม 1,500px
      // แถวรายการจะกางจนตัวเลขไปติดขอบขวา ห่างจากชื่อรายการจนอ่านลำบาก
      // บนมือถือจริงค่านี้ไม่มีผลเพราะจอแคบกว่าอยู่แล้ว
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: RefreshIndicator(
            onRefresh: _load,
            color: _acc,
            backgroundColor: _surface,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _acc));
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.cloud_off, color: _bad, size: 40),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _bad),
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(
                backgroundColor: _acc,
                foregroundColor: _bg,
              ),
              child: const Text('ลองใหม่'),
            ),
          ),
        ],
      );
    }

    final items = _page?.items ?? const <Expense>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        _SummaryCard(summary: _summary),
        const SizedBox(height: 14),
        _FilterBar(
          from: _from,
          to: _to,
          category: _filter,
          onChanged: (from, to, cat) {
            setState(() {
              _from = from;
              _to = to;
              _filter = cat;
            });
            _load();
          },
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'ไม่มีรายการในช่วงที่เลือก',
                style: TextStyle(color: _muted),
              ),
            ),
          )
        else
          ...items.map(
            (e) => _ExpenseTile(
              expense: e,
              onEdit: () => _openSheet(existing: e),
              onDelete: () => _delete(e),
            ),
          ),
        if (_page != null && _page!.totalItems > items.length)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(
              child: Text(
                'แสดง ${items.length} จาก ${_page!.totalItems} รายการ',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

// ── สรุป ──────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final Summary summary;

  @override
  Widget build(BuildContext context) {
    final max = summary.byCategory.isEmpty
        ? 1.0
        : summary.byCategory
              .map((c) => c.total)
              .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รวมทั้งหมด',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _money.format(summary.grandTotal),
                style: const TextStyle(
                  color: _acc,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              const Text('บาท', style: TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          for (final c in summary.byCategory) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.category.label,
                    style: const TextStyle(color: _text, fontSize: 13),
                  ),
                ),
                Text(
                  _money.format(c.total),
                  style: const TextStyle(color: _text, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (c.total / max).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: _raised,
                valueColor: AlwaysStoppedAnimation(
                  Color.lerp(_acc, _warn, c.total / max)!,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${c.count} รายการ',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
            const SizedBox(height: 10),
          ],
          if (summary.byCategory.isEmpty)
            const Text(
              'ยังไม่มีข้อมูล',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

// ── ตัวกรอง ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.from,
    required this.to,
    required this.category,
    required this.onChanged,
  });

  final DateTime from;
  final DateTime to;
  final Category? category;
  final void Function(DateTime from, DateTime to, Category? cat) onChanged;

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: from, end: to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: _acc, surface: _surface),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChanged(picked.start, picked.end, category);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: const Icon(Icons.date_range, size: 16, color: _muted),
          label: Text(
            '${_day.format(from)} → ${_day.format(to)}',
            style: const TextStyle(fontSize: 12, color: _text),
          ),
          backgroundColor: _raised,
          side: const BorderSide(color: _line),
          onPressed: () => _pickRange(context),
        ),
        for (final c in [null, ...Category.values])
          FilterChip(
            label: Text(
              c?.label ?? 'ทั้งหมด',
              style: const TextStyle(fontSize: 12),
            ),
            selected: category == c,
            onSelected: (_) => onChanged(from, to, c),
            backgroundColor: _raised,
            selectedColor: _acc.withValues(alpha: 0.18),
            checkmarkColor: _acc,
            side: BorderSide(color: category == c ? _acc : _line),
            labelStyle: TextStyle(color: category == c ? _acc : _muted),
          ),
      ],
    );
  }
}

// ── แถวรายการ ─────────────────────────────────────────────────────────────

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _bad.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: _bad),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // ให้ปุ่มยืนยันเป็นคนตัดสิน ไม่ลบทันทีที่ปัด
      },
      // แตะที่แถวเพื่อแก้ไข — บนมือถือการแตะทั้งแถวง่ายกว่าเล็งปุ่มเล็ก ๆ
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _raised,
                              border: Border.all(color: _line),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              expense.category.label,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _day.format(expense.spentOn),
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                      if (expense.note != null && expense.note!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          expense.note!,
                          style: const TextStyle(color: _text, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _money.format(expense.amount),
                  style: const TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: _muted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── ฟอร์มเพิ่ม / แก้ไขรายการ ──────────────────────────────────────────────

class ExpenseSheet extends StatefulWidget {
  const ExpenseSheet({super.key, required this.api, this.existing});

  final ExpenseApi api;

  /// null = โหมดเพิ่ม, มีค่า = โหมดแก้ไข
  final Expense? existing;

  @override
  State<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<ExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtl = TextEditingController();
  final _noteCtl = TextEditingController();

  late Category _category;
  late DateTime _spentOn;
  bool _saving = false;
  String? _serverError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e?.category ?? Category.food;
    _spentOn = e?.spentOn ?? DateTime.now();
    if (e != null) {
      // ตัดศูนย์ท้ายทิ้ง 250.00 -> 250 ให้พิมพ์แก้ง่าย
      _amountCtl.text = e.amount == e.amount.roundToDouble()
          ? e.amount.toStringAsFixed(0)
          : e.amount.toString();
      _noteCtl.text = e.note ?? '';
    }
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _serverError = null;
    });

    try {
      final amount = double.parse(_amountCtl.text.trim());
      final note = _noteCtl.text.trim();

      if (_isEdit) {
        await widget.api.update(
          widget.existing!.id,
          amount: amount,
          category: _category,
          spentOn: _spentOn,
          note: note,
        );
      } else {
        await widget.api.create(
          amount: amount,
          category: _category,
          spentOn: _spentOn,
          note: note,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // ถ้า API ชี้ field ที่ผิดมา แสดงข้อความนั้น
        _serverError = e.fieldErrors.values.firstOrNull ?? e.message;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverError = 'เชื่อมต่อ API ไม่ได้';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'แก้ไขรายการ' : 'เพิ่มรายการ',
              style: TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _amountCtl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: _text),
              decoration: const InputDecoration(
                labelText: 'จำนวนเงิน',
                labelStyle: TextStyle(color: _muted),
                hintText: '0.00',
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'กรอกจำนวนเงินมากกว่า 0';
                return null;
              },
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<Category>(
              initialValue: _category,
              dropdownColor: _raised,
              style: const TextStyle(color: _text),
              decoration: const InputDecoration(
                labelText: 'หมวด',
                labelStyle: TextStyle(color: _muted),
              ),
              items: [
                for (final c in Category.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (c) => setState(() => _category = c ?? Category.other),
            ),
            const SizedBox(height: 12),

            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _spentOn,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _spentOn = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'วันที่',
                  labelStyle: TextStyle(color: _muted),
                ),
                child: Text(
                  _day.format(_spentOn),
                  style: const TextStyle(color: _text),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _noteCtl,
              maxLength: 255,
              style: const TextStyle(color: _text),
              decoration: const InputDecoration(
                labelText: 'บันทึกช่วยจำ (ไม่บังคับ)',
                labelStyle: TextStyle(color: _muted),
                counterText: '',
              ),
            ),

            if (_serverError != null) ...[
              const SizedBox(height: 10),
              Text(
                _serverError!,
                style: const TextStyle(color: _bad, fontSize: 13),
              ),
            ],

            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _acc,
                  foregroundColor: const Color(0xFF04100E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _saving
                      ? 'กำลังบันทึก…'
                      : (_isEdit ? 'บันทึกการแก้ไข' : 'เพิ่ม'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
