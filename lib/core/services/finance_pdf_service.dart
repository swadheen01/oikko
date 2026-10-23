import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/transaction.dart';
import '../locale/locale_service.dart';
import 'finance_service.dart';

/// Builds a shareable PDF of the association finances — either the
/// association-wide summary (admin) or a single member's statement — and
/// hands it to the OS share/print sheet.
///
/// Bengali handling: the `pdf` package renders glyphs in code-point order
/// with no complex-script shaping, so Bengali conjuncts and reordered vowel
/// signs come out broken. Anything containing Bengali is therefore rendered
/// through Flutter's own text engine (`dart:ui`, which shapes correctly)
/// into a small image and embedded, while pure-Latin text (numbers, dates,
/// English labels) stays as real, selectable PDF text.
class FinancePdfService {
  FinancePdfService._();

  static const _assocName =
      'Bangladesh Teachers Association, Baniyachong Branch, Habiganj';

  /// Supersampling factor for the text-as-image path, so Bengali stays crisp
  /// when the PDF is zoomed or printed.
  static const double _imgScale = 3.0;

  static final RegExp _bengali = RegExp(r'[ঀ-৿]');
  static bool _hasBengali(String s) => _bengali.hasMatch(s);

  static pw.Font? _font;

  static Future<pw.Font> _loadFont() async {
    _font ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Kalpurush.ttf'));
    return _font!;
  }

  static String _tk(num amount) =>
      'Tk ${NumberFormat('#,##0.00', 'en_US').format(amount)}';

  // Matches the app's own transaction labels (transaction_list_item.dart):
  // a `duePayment` is a member paying their dues (চাঁদা জমা) — money paid IN,
  // not an amount owed. "Due payment" wrongly read as "outstanding", so it's
  // "Dues" / "চাঁদা জমা" here.
  static String _typeLabel(TransactionType t) {
    final isEn = LocaleService.isEnglish;
    switch (t) {
      case TransactionType.income:
        return isEn ? 'Income' : 'আয়';
      case TransactionType.expense:
        return isEn ? 'Expense' : 'ব্যয়';
      case TransactionType.withdrawal:
        return isEn ? 'Withdrawal' : 'টাকা উত্তোলন';
      case TransactionType.duePayment:
        return isEn ? 'Dues' : 'চাঁদা জমা';
    }
  }

  /// A single cell/line: real PDF text for Latin, a shaped image for Bengali.
  static Future<pw.Widget> _line(
    String text, {
    double fontSize = 9,
    PdfColor color = PdfColors.black,
    bool bold = false,
    double maxWidth = 240,
  }) async {
    if (!_hasBengali(text)) {
      return pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      );
    }

    final uiColor = ui.Color.fromARGB(
      255,
      (color.red * 255).round(),
      (color.green * 255).round(),
      (color.blue * 255).round(),
    );
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.left,
      fontSize: fontSize * _imgScale,
      fontFamily: 'Kalpurush',
      fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
    ))
      ..pushStyle(ui.TextStyle(
        color: uiColor,
        fontFamily: 'Kalpurush',
        fontSize: fontSize * _imgScale,
      ))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth * _imgScale));

    final w = paragraph.longestLine.ceil().clamp(1, 100000);
    final h = paragraph.height.ceil().clamp(1, 100000);

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawParagraph(paragraph, ui.Offset.zero);
    final image = await recorder.endRecording().toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return pw.Image(
      pw.MemoryImage(bytes!.buffer.asUint8List()),
      width: w / _imgScale,
      height: h / _imgScale,
      dpi: 72 * _imgScale,
    );
  }

  /// Association-wide financial summary (admin).
  static Future<void> shareAdminSummary({
    required List<AppTransaction> transactions,
    required Map<String, String> memberNames,
  }) async {
    final font = await _loadFont();
    final income = FinanceService.totalIncome(transactions);
    final expense = FinanceService.totalExpense(transactions);
    final balance = income - expense;
    final dateFmt = DateFormat('dd MMM yyyy');

    // Bengali cells (member names / descriptions) and the footer are shaped
    // to images up front, since that work is async and the page builder
    // below must be synchronous.
    final detailCells = <pw.Widget>[
      for (final t in transactions) await _line(_detailsFor(t, memberNames)),
    ];
    final typeCells = <pw.Widget>[
      for (final t in transactions) await _line(_typeLabel(t.type)),
    ];
    final footer = await _footer();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: font),
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _header('Financial Summary'),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _statBox('Total collected', _tk(income), PdfColors.teal700),
              pw.SizedBox(width: 8),
              _statBox('Total expense', _tk(expense), PdfColors.red700),
              pw.SizedBox(width: 8),
              _statBox('Net balance', _tk(balance), PdfColors.blue800),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text('${transactions.length} records',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 14),
          _table(
            headers: ['Date', 'Member / details', 'Type', 'Amount'],
            rows: [
              for (var i = 0; i < transactions.length; i++)
                [
                  pw.Text(dateFmt.format(transactions[i].date),
                      style: const pw.TextStyle(fontSize: 9)),
                  detailCells[i],
                  typeCells[i],
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(_tk(transactions[i].amount),
                        style: const pw.TextStyle(fontSize: 9)),
                  ),
                ],
            ],
          ),
          pw.SizedBox(height: 20),
          footer,
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'oikko-financial-summary.pdf',
    );
  }

  /// One member's personal statement.
  static Future<void> shareMemberStatement({
    required List<AppTransaction> transactions,
    required String memberName,
    String memberCode = '',
  }) async {
    final font = await _loadFont();
    final totalDeposit = FinanceService.totalIncome(transactions);
    final totalWithdrawal = FinanceService.totalExpense(transactions);
    final netBalance = FinanceService.balance(transactions);
    final dateFmt = DateFormat('dd MMM yyyy');

    final nameLine =
        await _line(memberName, fontSize: 15, bold: true, maxWidth: 400);
    final detailCells = <pw.Widget>[
      for (final t in transactions) await _line(t.description),
    ];
    final typeCells = <pw.Widget>[
      for (final t in transactions) await _line(_typeLabel(t.type)),
    ];
    final footer = await _footer();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: font),
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _header('Payment Statement'),
          pw.SizedBox(height: 12),
          nameLine,
          if (memberCode.isNotEmpty)
            pw.Text('Member ID: $memberCode',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 14),
          if (totalWithdrawal > 0)
            pw.Row(
              children: [
                _statBox('Total deposit', _tk(totalDeposit), PdfColors.teal700),
                pw.SizedBox(width: 8),
                _statBox('Withdrawal', _tk(totalWithdrawal), PdfColors.red700),
                pw.SizedBox(width: 8),
                _statBox('Net balance', _tk(netBalance), PdfColors.blue800),
                pw.SizedBox(width: 8),
                _statBox('Records', '${transactions.length}', PdfColors.grey800),
              ],
            )
          else
            pw.Row(
              children: [
                _statBox('Total paid', _tk(totalDeposit), PdfColors.teal700),
                pw.SizedBox(width: 8),
                _statBox('Payments', '${transactions.length}', PdfColors.blue800),
              ],
            ),
          pw.SizedBox(height: 14),
          _table(
            headers: ['Date', 'Details', 'Type', 'Amount'],
            rows: [
              for (var i = 0; i < transactions.length; i++)
                [
                  pw.Text(dateFmt.format(transactions[i].date),
                      style: const pw.TextStyle(fontSize: 9)),
                  detailCells[i],
                  typeCells[i],
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      (transactions[i].type == TransactionType.withdrawal ||
                              transactions[i].type == TransactionType.expense)
                          ? '- ${_tk(transactions[i].amount)}'
                          : '+ ${_tk(transactions[i].amount)}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: (transactions[i].type == TransactionType.withdrawal ||
                                transactions[i].type == TransactionType.expense)
                            ? PdfColors.red700
                            : PdfColors.teal800,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
            ],
          ),
          pw.SizedBox(height: 20),
          footer,
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'oikko-statement.pdf',
    );
  }

  static String _detailsFor(AppTransaction t, Map<String, String> names) {
    if (t.donorName != null && t.donorName!.isNotEmpty) {
      final desc = t.description.isNotEmpty ? ' (${t.description})' : '';
      return 'অনুদান: ${t.donorName}$desc';
    }
    final name = t.memberId == null ? '' : (names[t.memberId] ?? '');
    if (name.isNotEmpty) {
      if (t.description.isNotEmpty) return '$name (${t.description})';
      return name;
    }
    if (t.schoolName != null && t.schoolName!.isNotEmpty) {
      if (t.description.isNotEmpty) return '${t.schoolName} (${t.description})';
      return t.schoolName!;
    }
    if (t.category != null && t.category!.isNotEmpty) {
      if (t.description.isNotEmpty) return '${t.category}: ${t.description}';
      return t.category!;
    }
    if (t.description.isNotEmpty) return t.description;
    return t.memberId == null ? 'General' : '-';
  }

  /// Generates a PDF statement for a specific school.
  static Future<void> shareSchoolStatement({
    required String schoolName,
    required List<AppTransaction> transactions,
    required Map<String, String> memberNames,
  }) async {
    final font = await _loadFont();
    final totalDeposit = transactions
        .where((t) => t.type == TransactionType.duePayment || t.type == TransactionType.income)
        .fold(0.0, (acc, t) => acc + t.amount);
    final totalWithdrawal = transactions
        .where((t) => t.type == TransactionType.withdrawal || t.type == TransactionType.expense)
        .fold(0.0, (acc, t) => acc + t.amount);
    final netBalance = totalDeposit - totalWithdrawal;
    final dateFmt = DateFormat('dd MMM yyyy');

    final schoolLine =
        await _line(schoolName, fontSize: 15, bold: true, maxWidth: 420);
    final detailCells = <pw.Widget>[
      for (final t in transactions) await _line(_detailsFor(t, memberNames)),
    ];
    final typeCells = <pw.Widget>[
      for (final t in transactions) await _line(_typeLabel(t.type)),
    ];
    final footer = await _footer();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: font),
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _header('School Financial Statement / বিদ্যালয়ভিত্তিক হিসাব বিবরণী'),
          pw.SizedBox(height: 12),
          schoolLine,
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _statBox('Total deposit / মোট জমা', _tk(totalDeposit), PdfColors.teal700),
              pw.SizedBox(width: 8),
              _statBox('Withdrawal / উত্তোলন', _tk(totalWithdrawal), PdfColors.red700),
              pw.SizedBox(width: 8),
              _statBox('Net balance / নিট স্থিতি', _tk(netBalance), PdfColors.blue800),
              pw.SizedBox(width: 8),
              _statBox('Records / মোট লেনদেন', '${transactions.length}', PdfColors.grey800),
            ],
          ),
          pw.SizedBox(height: 14),
          _table(
            headers: ['Date / তারিখ', 'Details / বিবরণ ও খাত', 'Type / ধরন', 'Amount / পরিমাণ'],
            rows: [
              for (var i = 0; i < transactions.length; i++)
                [
                  pw.Text(dateFmt.format(transactions[i].date),
                      style: const pw.TextStyle(fontSize: 9)),
                  detailCells[i],
                  typeCells[i],
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      (transactions[i].type == TransactionType.withdrawal ||
                              transactions[i].type == TransactionType.expense)
                          ? '- ${_tk(transactions[i].amount)}'
                          : '+ ${_tk(transactions[i].amount)}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: (transactions[i].type == TransactionType.withdrawal ||
                                transactions[i].type == TransactionType.expense)
                            ? PdfColors.red700
                            : PdfColors.teal800,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
            ],
          ),
          pw.SizedBox(height: 20),
          footer,
        ],
      ),
    );

    final safeName = schoolName.replaceAll(RegExp(r'[^\w\s\u0980-\u09FF]'), '').trim();
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'oikko-school-statement-${safeName.isEmpty ? 'school' : safeName}.pdf',
    );
  }

  /// Generates a PDF summary of all schools with deposits, withdrawals, and balance.
  static Future<void> shareAllSchoolsSummary({
    required List<SchoolFinanceSummary> summaries,
  }) async {
    final font = await _loadFont();
    final totalDeposit = summaries.fold(0.0, (acc, s) => acc + s.totalDeposit);
    final totalWithdrawal = summaries.fold(0.0, (acc, s) => acc + s.totalWithdrawal);
    final netBalance = totalDeposit - totalWithdrawal;

    final schoolNameCells = <pw.Widget>[
      for (final s in summaries) await _line(s.schoolName, fontSize: 8.5, maxWidth: 200),
    ];
    final footer = await _footer();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: font),
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _header('All Schools Financial Summary / সকল বিদ্যালয়ের হিসাব সারসংক্ষেপ'),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _statBox('Total collected / মোট জমা', _tk(totalDeposit), PdfColors.teal700),
              pw.SizedBox(width: 8),
              _statBox('Total withdrawal / মোট উত্তোলন', _tk(totalWithdrawal), PdfColors.red700),
              pw.SizedBox(width: 8),
              _statBox('Net balance / মোট স্থিতি', _tk(netBalance), PdfColors.blue800),
              pw.SizedBox(width: 8),
              _statBox('Schools / বিদ্যালয়', '${summaries.length}', PdfColors.grey800),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.8),
              1: pw.FlexColumnWidth(4.0),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(2.0),
              4: pw.FlexColumnWidth(2.0),
              5: pw.FlexColumnWidth(2.0),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  for (final h in ['#', 'School / বিদ্যালয়', 'Teachers', 'Deposit', 'Withdrawal', 'Balance'])
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        textAlign: h == '#' ? pw.TextAlign.center : (h == 'School / বিদ্যালয়' ? pw.TextAlign.left : pw.TextAlign.right),
                      ),
                    ),
                ],
              ),
              for (var i = 0; i < summaries.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : PdfColors.grey50),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: schoolNameCells[i],
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: pw.Text('${summaries[i].memberCount}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: pw.Text(_tk(summaries[i].totalDeposit), style: const pw.TextStyle(fontSize: 8, color: PdfColors.teal800), textAlign: pw.TextAlign.right),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: pw.Text(_tk(summaries[i].totalWithdrawal), style: const pw.TextStyle(fontSize: 8, color: PdfColors.red700), textAlign: pw.TextAlign.right),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: pw.Text(_tk(summaries[i].balance), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: summaries[i].balance >= 0 ? PdfColors.blue800 : PdfColors.red800), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 20),
          footer,
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'oikko-all-schools-financial-summary.pdf',
    );
  }

  // ---------- shared pieces ----------

  static pw.Widget _header(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_assocName,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(title,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.blue800)),
        pw.SizedBox(height: 6),
        pw.Text(
          'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _statBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  /// A bordered table whose cells are arbitrary widgets (so a Bengali cell
  /// can be an image), styled to match the previous TableHelper output.
  static pw.Widget _table({
    required List<String> headers,
    required List<List<pw.Widget>> rows,
  }) {
    pw.Widget cell(pw.Widget child) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: child,
        );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(4),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue800),
          children: [
            for (var i = 0; i < headers.length; i++)
              cell(pw.Align(
                alignment:
                    i == 3 ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                child: pw.Text(headers[i],
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              )),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              for (final c in row)
                cell(pw.Align(alignment: pw.Alignment.centerLeft, child: c)),
            ],
          ),
      ],
    );
  }

  static Future<pw.Widget> _footer() async {
    final tagline = LocaleService.isEnglish
        ? 'Generated by the Oikko app.'
        : 'Oikko অ্যাপ থেকে তৈরি।';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.grey400),
        await _line(tagline, fontSize: 9, color: PdfColors.grey600, maxWidth: 400),
      ],
    );
  }
}
