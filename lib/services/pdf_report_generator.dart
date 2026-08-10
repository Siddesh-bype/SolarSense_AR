// lib/services/pdf_report_generator.dart
//
// Fully on-device PDF generator — no backend, no OpenAI, no reportlab.
// Produces a 16-section professional solar assessment PDF using the
// Dart `pdf` package. Charts are drawn as native PDF vector graphics.
//
// Port of report Module/report_generator.py. AI-written paragraphs are
// replaced with template copy that interpolates the real numbers.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/enriched_scan_result.dart';
import '../core/solar/monthly_profile.dart';
import 'user_session.dart';

class PdfReportGenerator {
  PdfReportGenerator._();
  static final PdfReportGenerator instance = PdfReportGenerator._();

  // ── Color palette ──────────────────────────────────────────────────────────
  static const _primary     = PdfColor.fromInt(0xFF2C3E50);
  static const _secondary   = PdfColor.fromInt(0xFF5D6D7E);
  static const _darkText    = PdfColor.fromInt(0xFF2C3E50);
  static const _greyText    = PdfColor.fromInt(0xFF717D7E);
  static const _softBorder  = PdfColor.fromInt(0xFFD5D8DC);
  static const _altRowBg    = PdfColor.fromInt(0xFFF4F6F7);
  static const _headerBg    = PdfColor.fromInt(0xFF34495E);
  static const _kpiBg       = PdfColor.fromInt(0xFFF8F9FA);
  static const _green       = PdfColor.fromInt(0xFF27AE60);
  static const _red         = PdfColor.fromInt(0xFFE74C3C);
  static const _orange      = PdfColor.fromInt(0xFFF39C12);
  static const _blue        = PdfColor.fromInt(0xFF2980B9);
  static const _palePink    = PdfColor.fromInt(0xFFF5CBA7);
  static const _paleYellow  = PdfColor.fromInt(0xFFF9E79F);
  static const _paleBlue    = PdfColor.fromInt(0xFFAED6F1);
  static const _paleGreen   = PdfColor.fromInt(0xFFA9DFBF);
  static const _palePurple  = PdfColor.fromInt(0xFFD7BDE2);
  static const _paleGrey    = PdfColor.fromInt(0xFFD5DBDB);

  Map<String, dynamic>? _staticData;
  pw.MemoryImage? _coverImg;

  Future<void> _loadAssets() async {
    if (_staticData == null) {
      final raw = await rootBundle
          .loadString('assets/data/report_static_data.json');
      _staticData = jsonDecode(raw) as Map<String, dynamic>;
    }
    if (_coverImg == null) {
      try {
        final bytes = await rootBundle.load('assets/report_cover.png');
        _coverImg = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {/* cover image optional */}
    }
  }

  /// Build the PDF bytes from the enriched scan result.
  Future<Uint8List> build(EnrichedScanResult d) async {
    await _loadAssets();

    final session = UserSession.instance;
    final now = DateTime.now();
    final reportId =
        'REP${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

    final ctx = _ReportContext.from(
      scan: d,
      session: session,
      reportId: reportId,
      now: now,
      staticData: _staticData ?? {},
    );

    final doc = pw.Document(
      title: 'SolarMitra - Solar Assessment Report',
      author: 'SolarMitra Report Engine',
    );

    // Cover — full-bleed, no header/footer.
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => _coverPage(ctx),
    ));

    // All other sections — auto-paginating MultiPage with header/footer.
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(
        marginTop: 18 * PdfPageFormat.mm,
        marginBottom: 18 * PdfPageFormat.mm,
        marginLeft: 15 * PdfPageFormat.mm,
        marginRight: 15 * PdfPageFormat.mm,
      ),
      header: _pageHeader,
      footer: _pageFooter,
      build: (ctx2) => _buildBody(ctx),
    ));

    return doc.save();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Headers / footers / cover
  // ───────────────────────────────────────────────────────────────────────────
  pw.Widget _coverPage(_ReportContext ctx) {
    final overlay = PdfColor(0.17, 0.24, 0.31, 0.70);
    return pw.Stack(children: [
      if (_coverImg != null)
        pw.Positioned.fill(
          child: pw.Image(_coverImg!, fit: pw.BoxFit.cover),
        ),
      pw.Positioned.fill(
        child: pw.Container(color: overlay),
      ),
      pw.Positioned.fill(
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 80),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(children: [
                pw.Text('SolarMitra',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Solar Assessment Report',
                    style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xFFD5D8DC), fontSize: 16)),
                pw.SizedBox(height: 16),
                pw.Container(
                    height: 1, width: 140, color: PdfColors.white),
                pw.SizedBox(height: 30),
                pw.Text('Prepared for: ${ctx.userName}',
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 14)),
                pw.SizedBox(height: 8),
                pw.Text('Location: ${ctx.locationLine}',
                    style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xFFD5D8DC), fontSize: 13)),
                pw.SizedBox(height: 6),
                pw.Text('Date: ${ctx.dateLine}',
                    style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xFFD5D8DC), fontSize: 13)),
                pw.SizedBox(height: 6),
                pw.Text('Report ID: ${ctx.reportId}',
                    style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xFFAEB6BF), fontSize: 11)),
              ]),
              pw.Text('SolarMitra Report Engine | v1.0',
                  style: const pw.TextStyle(
                      color: PdfColor.fromInt(0xFFAEB6BF), fontSize: 9)),
            ],
          ),
        ),
      ),
    ]);
  }

  pw.Widget _pageHeader(pw.Context c) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: _primary, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('SolarMitra',
              style: pw.TextStyle(
                  color: _primary,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold)),
          pw.Text('Solar Assessment Report',
              style: const pw.TextStyle(color: _greyText, fontSize: 8)),
        ],
      ),
    );
  }

  pw.Widget _pageFooter(pw.Context c) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
              'Generated by SolarMitra Report Engine  |  Confidential',
              style: const pw.TextStyle(color: _greyText, fontSize: 7)),
          pw.Text('Page ${c.pageNumber} / ${c.pagesCount}',
              style: const pw.TextStyle(color: _greyText, fontSize: 7)),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Body
  // ───────────────────────────────────────────────────────────────────────────
  List<pw.Widget> _buildBody(_ReportContext ctx) {
    return [
      ..._executiveSummary(ctx),
      ..._rooftopAnalysis(ctx),
      ..._arSnapshot(ctx),
      ..._systemDesign(ctx),
      ..._energyEstimate(ctx),
      ..._costBreakdown(ctx),
      ..._subsidyDetails(ctx),
      ..._subsidySchemeGuide(ctx),
      ..._savingsAnalysis(ctx),
      ..._roiAnalysis(ctx),
      ..._providerComparison(ctx),
      ..._environmentalImpact(ctx),
      ..._assumptions(ctx),
      ..._disclaimer(ctx),
      ..._contact(ctx),
    ];
  }

  // ── Section 1: Executive Summary ──────────────────────────────────────────
  List<pw.Widget> _executiveSummary(_ReportContext c) {
    return [
      _sectionTitle('1. Executive Summary'),
      _divider(),
      _para(
        'This report summarises the solar rooftop assessment performed for '
        '${c.userName} at ${c.locationLine}. Based on an AR-measured usable '
        'roof area of ${c.usableArea.toStringAsFixed(1)} sq.m and local '
        'irradiance of ${c.sunHours.toStringAsFixed(1)} peak-sun hours/day, '
        'we recommend a ${c.systemKw.toStringAsFixed(2)} kW grid-tied '
        'system. The net installation cost after the PM Surya Ghar subsidy '
        'is ${_rs(c.netCost)}, with an estimated payback of '
        '${c.paybackYears.toStringAsFixed(1)} years and lifetime savings of '
        '${_rs(c.lifetimeSavings)} over 25 years.',
      ),
      pw.SizedBox(height: 8),
      _kpiRow([
        ['${c.systemKw.toStringAsFixed(2)} kW', 'System Size'],
        [_rs(c.grossCost), 'Total Cost'],
        [_rs(c.totalSubsidy), 'Govt. Subsidy'],
      ]),
      pw.SizedBox(height: 6),
      _kpiRow([
        [_rs(c.netCost), 'Net Payable'],
        ['${c.paybackYears.toStringAsFixed(1)} yrs', 'Payback Period'],
        ['${c.roiPct.toStringAsFixed(0)}%', '25-Year ROI'],
      ]),
      pw.SizedBox(height: 14),
    ];
  }

  // ── Section 2: Rooftop Analysis ──────────────────────────────────────────
  List<pw.Widget> _rooftopAnalysis(_ReportContext c) {
    final obstacles = c.obstacleDesc;
    return [
      _sectionTitle('2. Rooftop Analysis'),
      _divider(),
      _para(
        'Our AR scan measured ${c.totalArea.toStringAsFixed(1)} sq.m of total '
        'rooftop surface, of which ${c.usableArea.toStringAsFixed(1)} sq.m '
        'is usable for panel placement after accounting for obstructions and '
        'shading margins. This is enough room for ${c.panelCount} panels '
        'delivering a ${c.systemKw.toStringAsFixed(2)} kW system.',
      ),
      pw.SizedBox(height: 8),
      _kvTable([
        ['Total Rooftop Area', '${c.totalArea.toStringAsFixed(1)} sq.m'],
        ['Usable Area (after obstacles)', '${c.usableArea.toStringAsFixed(1)} sq.m'],
        ['Obstacle Area',
          '${math.max(0, c.totalArea - c.usableArea).toStringAsFixed(1)} sq.m'],
        ['Obstacles Identified', obstacles],
        ['Panels That Fit', '${c.panelCount} panels (2.58 sq.m each)'],
      ]),
      pw.SizedBox(height: 8),
      _para(
        '<b>Panel Layout:</b> ${c.panelCount} panels arranged for maximum '
        'sun exposure, south-facing at 18° tilt.',
      ),
      pw.SizedBox(height: 10),
    ];
  }

  // ── Section 2b: AR capture snapshot ──────────────────────────────────────
  List<pw.Widget> _arSnapshot(_ReportContext c) {
    final bytes = c.arSnapshot;
    if (bytes == null || bytes.isEmpty) return [];
    pw.ImageProvider? img;
    try {
      img = pw.MemoryImage(bytes);
    } catch (_) {
      return [];
    }
    final heading = c.scanHeadingDeg;
    final headingTxt = heading != null
        ? '  •  Captured facing ${heading.round()}° (compass)'
        : '';
    return [
      _sectionTitle('2b. AR Rooftop Capture'),
      _divider(),
      _para(
        'The image below is the AR snapshot taken during your on-device scan. '
        'Panel placement and obstacle detection run directly on this frame — no '
        'photo leaves the device.$headingTxt',
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        height: 180,
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _softBorder, width: 0.5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 6,
          verticalRadius: 6,
          child: pw.Image(img!, fit: pw.BoxFit.cover),
        ),
      ),
      pw.SizedBox(height: 10),
    ];
  }

  // ── Section 3: System Design ─────────────────────────────────────────────
  List<pw.Widget> _systemDesign(_ReportContext c) {
    return [
      _sectionTitle('3. Solar System Design'),
      _divider(),
      _para(
        'The recommended system is sized to match your roof capacity and '
        'local generation potential. Monocrystalline panels deliver the best '
        'performance-per-square-metre and pair with a ${(c.systemKw * 1.25).toStringAsFixed(1)} kW '
        'string inverter for high conversion efficiency. Expected useful life '
        'is 25 years at a mild ~0.5%/yr degradation rate.',
      ),
      pw.SizedBox(height: 8),
      _kvTable([
        ['System Size', '${c.systemKw.toStringAsFixed(2)} kW'],
        ['Number of Panels', '${c.panelCount}'],
        ['Panel Model', '${c.panelWatt}W Mono PERC'],
        ['Panel Wattage', '${c.panelWatt} W'],
        ['Panel Type', 'Monocrystalline'],
        ['Inverter', 'Growatt ${(c.systemKw * 1.25).toStringAsFixed(1)} kW (String Inverter)'],
        ['System Efficiency', '18%'],
        ['Expected Lifetime', '25 years'],
        ['Annual Degradation', '0.5%'],
      ]),
      pw.SizedBox(height: 10),
    ];
  }

  // ── Section 4: Energy Generation ──────────────────────────────────────────
  List<pw.Widget> _energyEstimate(_ReportContext c) {
    final monthly = c.monthlyBreakdown;
    return [
      _sectionTitle('4. Energy Generation Estimate'),
      _divider(),
      _para(
        'Using PVGIS-derived irradiance data (${c.sunHours.toStringAsFixed(1)} '
        'peak-sun hours/day for your location), your system should generate '
        'approximately ${c.annualKwh.round()} kWh annually — '
        '${(c.annualKwh / 12).round()} kWh per month on average. Output '
        'peaks in summer (Apr–Jun) and dips during the monsoon (Jul–Aug).',
      ),
      pw.SizedBox(height: 8),
      _kvTable([
        ['Monthly Generation (avg)', '${(c.annualKwh / 12).round()} kWh'],
        ['Annual Generation', '${c.annualKwh.round()} kWh'],
        ['Performance Ratio', '75%'],
        ['Avg Sun Hours / Day', '${c.sunHours.toStringAsFixed(1)} hrs'],
      ]),
      pw.SizedBox(height: 10),
      _monthlyBarChart(monthly),
      pw.SizedBox(height: 10),
    ];
  }

  // ── Section 5: Cost Breakdown ─────────────────────────────────────────────
  List<pw.Widget> _costBreakdown(_ReportContext c) {
    final breakdown = c.costBreakdown;
    final rows = breakdown.entries
        .map((e) => [_titleCase(e.key.replaceAll('_', ' ')), _rs(e.value)])
        .toList();
    rows.add(['Total', _rs(c.grossCost)]);

    return [
      _sectionTitle('5. Cost Breakdown'),
      _divider(),
      _para(
        'Total installation works out to ${_rs(c.grossCost)} (about '
        'Rs. ${c.pricePerWatt}/watt). The breakdown below separates hardware '
        '(panels + inverter + mounting) from labour and net-metering fees — '
        'helpful when comparing quotes from vendors.',
      ),
      pw.SizedBox(height: 6),
      _para(
        '<b>Price per Watt:</b> Rs. ${c.pricePerWatt}/W &nbsp;&nbsp;|&nbsp;&nbsp;'
        '<b>Total Installation Cost:</b> ${_rs(c.grossCost)}',
      ),
      pw.SizedBox(height: 6),
      _kvTable(rows, headers: ['Component', 'Cost']),
      pw.SizedBox(height: 10),
      _costPieChart(breakdown),
      pw.SizedBox(height: 10),
    ];
  }

  // ── Section 6: Subsidy Details ────────────────────────────────────────────
  List<pw.Widget> _subsidyDetails(_ReportContext c) {
    return [
      _sectionTitle('6. Government Subsidy Details'),
      _divider(),
      _para(
        'Your system qualifies for the PM Surya Ghar Muft Bijli Yojana. '
        'Central assistance of ${_rs(c.centralSubsidy)} applies; '
        '${c.stateSubsidy > 0 ? "your state adds a further ${_rs(c.stateSubsidy)} on top. " : ""}'
        'After subsidy, your out-of-pocket cost drops to ${_rs(c.netCost)} — '
        'a ${c.subsidyPct.toStringAsFixed(0)}% reduction versus the sticker price.',
      ),
      pw.SizedBox(height: 8),
      _kvTable([
        ['Scheme Name', 'PM Surya Ghar Muft Bijli Yojana'],
        ['Eligible', c.totalSubsidy > 0 ? 'Yes' : 'No'],
        ['Subsidy Amount', _rs(c.totalSubsidy)],
        ['Subsidy as % of Cost', '${c.subsidyPct.toStringAsFixed(1)}%'],
        ['Subsidy Calculation',
          'Central: ${_rs(c.centralSubsidy)}'
          '${c.stateSubsidy > 0 ? " + State: ${_rs(c.stateSubsidy)}" : ""}'],
        ['Final Cost After Subsidy', _rs(c.netCost)],
      ]),
      pw.SizedBox(height: 10),
    ];
  }

  // ── Section 7: Subsidy Scheme Guide (static data) ─────────────────────────
  List<pw.Widget> _subsidySchemeGuide(_ReportContext c) {
    final guide = c.staticData['subsidy_scheme_guide'] as Map<String, dynamic>?;
    if (guide == null) return [];

    final out = <pw.Widget>[];
    out.add(_sectionTitle('7. PM Surya Ghar Yojana - Complete Guide'));
    out.add(_divider());
    out.add(_para(
      'The Pradhan Mantri Surya Ghar Muft Bijli Yojana is the Government of '
      'India\'s flagship rooftop-solar scheme. Below is a complete reference '
      'you can follow to claim the subsidy applicable to your project.',
    ));
    out.add(pw.SizedBox(height: 6));
    out.add(_para(
      '<b>Official Portal:</b> ${guide["official_website"]} &nbsp;|&nbsp; '
      '<b>Helpline:</b> ${guide["helpline"]}',
    ));
    out.add(_para(
      '<b>Launched:</b> ${guide["launched"]} &nbsp;|&nbsp; '
      '<b>Total Outlay:</b> Rs. ${_numFmt(guide["total_outlay_crore"])} Crore &nbsp;|&nbsp; '
      '<b>Target:</b> ${guide["target"]}',
    ));
    out.add(pw.SizedBox(height: 8));

    // Subsidy slabs table
    out.add(_subSection('Subsidy Structure (Central Financial Assistance)'));
    final slabs = (guide['subsidy_slabs'] as List).cast<Map<String, dynamic>>();
    out.add(_styledTable(
      headers: ['System Capacity', 'Benchmark Cost', 'Subsidy %',
                'Subsidy Amount', 'Your Net Cost'],
      rows: slabs.map((s) => [
        s['capacity'].toString(),
        'Rs. ${s["benchmark_cost"]}',
        s['subsidy_percent'].toString(),
        _rs(s['subsidy_amount'] as num),
        'Rs. ${s["net_cost_range"]}',
      ]).toList(),
      colFlex: const [3, 3, 2, 3, 3],
    ));
    out.add(pw.SizedBox(height: 8));

    out.add(_subSection('How Subsidy is Calculated'));
    final formula = (guide['calculation_formula'] as List).cast<String>();
    for (var i = 0; i < formula.length; i++) {
      out.add(_para('${i + 1}. ${formula[i]}'));
    }
    out.add(pw.SizedBox(height: 6));

    out.add(_subSection('Eligibility Criteria'));
    final elig = (guide['eligibility'] as List).cast<String>();
    for (final e in elig) {
      out.add(_bullet(e));
    }
    out.add(pw.SizedBox(height: 6));

    out.add(_subSection('Required Documents'));
    final docs = (guide['required_documents'] as List).cast<Map<String, dynamic>>();
    out.add(_styledTable(
      headers: ['Document', 'Purpose'],
      rows: docs.map((d) =>
          [d['document'].toString(), d['purpose'].toString()]).toList(),
      colFlex: const [2, 3],
    ));
    out.add(pw.SizedBox(height: 6));

    out.add(_subSection('Step-by-Step Application Process'));
    final steps = (guide['application_steps'] as List).cast<String>();
    for (var i = 0; i < steps.length; i++) {
      out.add(_para('<b>Step ${i + 1}:</b> ${steps[i]}'));
    }
    out.add(pw.SizedBox(height: 6));

    out.add(_subSection('Key Benefits'));
    final benefits = (guide['key_benefits'] as List).cast<Map<String, dynamic>>();
    out.add(_styledTable(
      headers: ['Benefit', 'Details'],
      rows: benefits.map((b) =>
          [b['benefit'].toString(), b['details'].toString()]).toList(),
      colFlex: const [1, 3],
    ));
    out.add(pw.SizedBox(height: 6));

    out.add(_subSection('State-Wise Additional Subsidies (on top of Central)'));
    final stateSubs = (guide['state_subsidies'] as List).cast<Map<String, dynamic>>();
    out.add(_styledTable(
      headers: ['State', 'Additional Subsidy', 'Portal', 'Notes'],
      rows: stateSubs.map((s) => [
        s['state'].toString(),
        s['additional_subsidy'].toString(),
        s['portal'].toString(),
        s['notes'].toString(),
      ]).toList(),
      colFlex: const [2, 3, 3, 3],
    ));
    out.add(pw.SizedBox(height: 6));

    out.add(_subSection('Financing Options'));
    final fin = (guide['financing_options'] as List).cast<Map<String, dynamic>>();
    out.add(_styledTable(
      headers: ['Bank / Lender', 'Loan Type', 'Interest Rate', 'Max Amount'],
      rows: fin.map((f) => [
        f['bank'].toString(),
        f['loan_type'].toString(),
        f['interest_rate'].toString(),
        _rs(f['max_amount'] as num),
      ]).toList(),
      colFlex: const [3, 3, 3, 2],
    ));
    out.add(pw.SizedBox(height: 6));

    out.add(_subSection('Important Rules & Restrictions'));
    for (final rule in (guide['important_rules'] as List).cast<String>()) {
      out.add(_bullet(rule));
    }
    out.add(pw.SizedBox(height: 6));

    out.add(_subSection('Important Contacts & Links'));
    final links = (guide['important_links'] as List).cast<Map<String, dynamic>>();
    out.add(_styledTable(
      headers: ['Resource', 'Link / Contact', 'Purpose'],
      rows: links.map((l) => [
        l['resource'].toString(),
        l['link'].toString(),
        l['purpose'].toString(),
      ]).toList(),
      colFlex: const [2, 3, 4],
    ));
    out.add(pw.SizedBox(height: 10));

    return out;
  }

  // ── Section 8: Savings ────────────────────────────────────────────────────
  List<pw.Widget> _savingsAnalysis(_ReportContext c) {
    return [
      _sectionTitle('8. Savings Analysis'),
      _divider(),
      _para(
        'At a grid tariff of Rs. ${c.tariff.toStringAsFixed(2)}/unit, the '
        'energy your system generates offsets roughly '
        '${_rs((c.annualSavings / 12).round())} of your monthly bill. Over '
        '25 years you stand to save approximately ${_rs(c.lifetimeSavings)} '
        '— a meaningful hedge against future tariff hikes.',
      ),
      pw.SizedBox(height: 8),
      _kvTable([
        ['Monthly Savings', _rs((c.annualSavings / 12).round())],
        ['Annual Savings', _rs(c.annualSavings)],
        ['25-Year Lifetime Savings', _rs(c.lifetimeSavings)],
      ]),
      pw.SizedBox(height: 10),
    ];
  }

  // ── Section 9: ROI ────────────────────────────────────────────────────────
  List<pw.Widget> _roiAnalysis(_ReportContext c) {
    return [
      _sectionTitle('9. ROI & Payback Analysis'),
      _divider(),
      _para(
        'Your system crosses the break-even line in year '
        '${c.paybackYears.ceil()}. Beyond that, every unit generated is pure '
        'savings — a 25-year ROI of about ${c.roiPct.toStringAsFixed(0)}% '
        'on your post-subsidy investment.',
      ),
      pw.SizedBox(height: 8),
      _kvTable([
        ['Payback Period', '${c.paybackYears.toStringAsFixed(1)} years'],
        ['ROI (25-year)', '${c.roiPct.toStringAsFixed(1)}%'],
        ['Break-even Year', 'Year ${c.paybackYears.ceil()}'],
      ]),
      pw.SizedBox(height: 10),
      _cashflowChart(c.cashflow),
      pw.SizedBox(height: 10),
    ];
  }

  // ── Section 10: Provider Comparison (static data) ─────────────────────────
  List<pw.Widget> _providerComparison(_ReportContext c) {
    final providers = (c.staticData['provider_comparison'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    if (providers.isEmpty) return [];

    final selected = providers.firstWhere(
      (p) => p['selected'] == true,
      orElse: () => providers.first,
    )['provider'].toString();

    return [
      _sectionTitle('10. Provider Comparison'),
      _divider(),
      _para(
        'All listed providers are ALMM-empanelled (eligible for PM Surya Ghar '
        'subsidy). Your shortlist is $selected, marked with an asterisk below. '
        'Prices shown are current market rates; per-watt prices vary with '
        'panel technology and regional logistics.',
      ),
      pw.SizedBox(height: 6),
      _para('<b>Selected Provider:</b> $selected'),
      pw.SizedBox(height: 6),
      _styledTable(
        headers: ['Provider', 'Rs./W Range', '3kW Cost', 'Efficiency',
                  'Warranty', 'Rating'],
        rows: providers.map((p) {
          final mark = p['selected'] == true ? ' *' : '';
          final scale = p['rating_scale'] ?? 10;
          return [
            '${p["provider"]}$mark',
            'Rs. ${p["price_per_watt_range"]}',
            _rs(p['total_cost'] as num),
            p['best_efficiency'].toString(),
            '${p["warranty_years"]} yrs',
            '${p["rating"]}/$scale',
          ];
        }).toList(),
        colFlex: const [4, 3, 3, 3, 2, 2],
      ),
      pw.SizedBox(height: 10),
      _providerChart(providers),
      pw.SizedBox(height: 10),
    ];
  }

  // ── Section 11: Environmental Impact ──────────────────────────────────────
  List<pw.Widget> _environmentalImpact(_ReportContext c) {
    return [
      _sectionTitle('11. Environmental Impact'),
      _divider(),
      _para(
        'Every kWh you generate avoids coal-fired grid emissions. Your system '
        'is projected to prevent ${c.co2PerYear.toStringAsFixed(1)} tonnes of '
        'CO₂ each year — equivalent to planting ${c.treesEquivalent} trees '
        'annually. Over 25 years that\'s '
        '${c.co2Lifetime.toStringAsFixed(1)} tonnes of carbon avoided.',
      ),
      pw.SizedBox(height: 8),
      _kpiRow([
        ['${c.co2PerYear.toStringAsFixed(1)} t/yr', 'CO2 Reduction'],
        ['${c.treesEquivalent}', 'Trees Equivalent'],
        ['${c.co2Lifetime.toStringAsFixed(0)} t', '25-Year CO2 Saved'],
      ]),
      pw.SizedBox(height: 10),
    ];
  }

  // ── Section 12: Assumptions ───────────────────────────────────────────────
  List<pw.Widget> _assumptions(_ReportContext c) {
    final a = (c.staticData['assumptions'] as Map<String, dynamic>?) ?? {};
    return [
      _sectionTitle('12. Assumptions & Notes'),
      _divider(),
      _para(
        'All numbers in this report rest on the assumptions tabled below. '
        'Real-world performance will vary with shading, dust, temperature, '
        'orientation and tariff changes — we recommend a physical site '
        'survey before signing a contract.',
      ),
      pw.SizedBox(height: 8),
      _kvTable([
        ['Electricity Tariff',
          'Rs. ${a["electricity_tariff_per_unit"] ?? c.tariff}/unit'],
        ['Annual Tariff Escalation',
          '${(((a["annual_tariff_escalation"] ?? 0.03) as num) * 100).toStringAsFixed(0)}%'],
        ['System Efficiency (Performance Ratio)',
          '${(((a["system_efficiency"] ?? 0.75) as num) * 100).toStringAsFixed(0)}%'],
        ['Panel Degradation / Year',
          '${(((a["panel_degradation_per_year"] ?? 0.005) as num) * 100).toStringAsFixed(1)}%'],
        ['Solar Irradiance',
          '${a["average_solar_irradiance_kwh_m2_day"] ?? c.sunHours} kWh/m²/day'],
        ['Grid Metering', (a['grid_availability'] ?? 'Net metering enabled').toString()],
        ['Inflation Rate',
          '${(((a["inflation_rate"] ?? 0.06) as num) * 100).toStringAsFixed(0)}%'],
      ]),
      pw.SizedBox(height: 8),
      _para(
        '<b>Limitations:</b> Estimates are based on average solar irradiance '
        'data and may not reflect micro-climate variations. Shadow analysis '
        'from AR is approximate. Actual generation depends on panel '
        'orientation, weather patterns, and maintenance.',
      ),
      pw.SizedBox(height: 10),
    ];
  }

  // ── Section 13: Disclaimer ────────────────────────────────────────────────
  List<pw.Widget> _disclaimer(_ReportContext c) {
    final text = ((c.staticData['disclaimer']
        as Map<String, dynamic>?)?['text'] ?? '') as String;
    return [
      _sectionTitle('13. Disclaimer'),
      _divider(),
      _para(text),
      pw.SizedBox(height: 10),
    ];
  }

  // ── Section 14: Contact / Next Steps ──────────────────────────────────────
  List<pw.Widget> _contact(_ReportContext c) {
    final contact = (c.staticData['contact'] as Map<String, dynamic>?) ?? {};
    final steps = (contact['next_steps'] as List?)?.cast<String>() ?? [];
    final out = <pw.Widget>[
      _sectionTitle('14. Contact & Next Steps'),
      _divider(),
      _para(
        'To move forward, schedule a site survey with a certified installer '
        'and begin your PM Surya Ghar application in parallel. The checklist '
        'below lays out the exact sequence.',
      ),
      pw.SizedBox(height: 6),
    ];
    if (contact['installer_name'] != null) {
      out.add(_kvTable([
        ['Installer', contact['installer_name'].toString()],
        ['Phone', (contact['phone'] ?? 'N/A').toString()],
        ['Email', (contact['email'] ?? 'N/A').toString()],
        ['Website', (contact['website'] ?? 'N/A').toString()],
      ]));
      out.add(pw.SizedBox(height: 8));
    }
    if (steps.isNotEmpty) {
      out.add(_para('<b>Recommended Next Steps:</b>'));
      for (var i = 0; i < steps.length; i++) {
        out.add(_para('${i + 1}. ${steps[i]}'));
      }
    }
    out.add(pw.SizedBox(height: 20));
    out.add(pw.Center(
      child: pw.Text(
        'Thank you for choosing SolarMitra.',
        style: pw.TextStyle(
            color: _primary, fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    ));
    out.add(pw.SizedBox(height: 6));
    out.add(pw.Center(
      child: pw.Text(
        'Save or share this report to take the next step towards clean energy.',
        style: const pw.TextStyle(color: _greyText, fontSize: 9),
      ),
    ));
    return out;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Charts
  // ───────────────────────────────────────────────────────────────────────────
  pw.Widget _monthlyBarChart(List<int> monthly) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final maxV = monthly.isEmpty
        ? 1.0
        : monthly.reduce(math.max).toDouble() * 1.15;

    return pw.Container(
      height: 160,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _softBorder, width: 0.4),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(children: [
        pw.Text('Monthly Energy Generation Estimate (kWh)',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: _primary)),
        pw.SizedBox(height: 6),
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: List.generate(12, (i) {
              final h = maxV > 0 ? (monthly[i] / maxV) : 0.0;
              return pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 1.5),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('${monthly[i]}',
                          style: const pw.TextStyle(
                              fontSize: 6, color: _greyText)),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        height: math.max(2.0, 110 * h),
                        decoration: const pw.BoxDecoration(
                          color: _orange,
                          borderRadius: pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(1.5),
                            topRight: pw.Radius.circular(1.5),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(months[i],
                          style: const pw.TextStyle(
                              fontSize: 7, color: _secondary)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  pw.Widget _cashflowChart(List<int> cashflow) {
    if (cashflow.isEmpty) return pw.SizedBox();
    final maxV = cashflow.reduce(math.max).toDouble();
    final minV = cashflow.reduce(math.min).toDouble();
    final range = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);

    return pw.Container(
      height: 180,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _softBorder, width: 0.4),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(children: [
        pw.Text('Cumulative Cash Flow Over 25 Years (Rs. \'000)',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: _primary)),
        pw.SizedBox(height: 4),
        pw.Expanded(
          child: pw.LayoutBuilder(builder: (ctx, constraints) {
            final h = constraints!.maxHeight;
            final zeroY = (maxV / range) * h;
            return pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: List.generate(cashflow.length, (i) {
                final fracH = ((cashflow[i] - minV) / range) * h;
                final isNeg = cashflow[i] < 0;
                return pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 0.8),
                    child: pw.Stack(children: [
                      // zero axis line
                      pw.Positioned(
                        left: 0, right: 0, top: zeroY,
                        child: pw.Container(
                            height: 0.4, color: _primary),
                      ),
                      pw.Align(
                        alignment: isNeg
                            ? pw.Alignment.topCenter
                            : pw.Alignment.bottomCenter,
                        child: pw.Container(
                          height: isNeg ? (zeroY - fracH) : (fracH - zeroY),
                          color: isNeg ? _red : _green,
                        ),
                      ),
                    ]),
                  ),
                );
              }),
            );
          }),
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Year 1',
                style: const pw.TextStyle(fontSize: 7, color: _greyText)),
            pw.Text('Year ${cashflow.length}',
                style: const pw.TextStyle(fontSize: 7, color: _greyText)),
          ],
        ),
      ]),
    );
  }

  pw.Widget _costPieChart(Map<String, int> breakdown) {
    final total = breakdown.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return pw.SizedBox();
    const palette = [_paleBlue, _paleGreen, _paleYellow,
                     _palePink, _palePurple, _paleGrey];
    final entries = breakdown.entries.toList();

    return pw.Container(
      height: 170,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _softBorder, width: 0.4),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Center(
              child: pw.SizedBox(
                width: 140, height: 140,
                child: pw.CustomPaint(
                  size: const PdfPoint(140, 140),
                  painter: (canvas, size) {
                    final cx = size.x / 2;
                    final cy = size.y / 2;
                    final r = math.min(cx, cy) - 2;
                    double startAngle = -math.pi / 2;
                    for (var i = 0; i < entries.length; i++) {
                      final sweep = entries[i].value / total * 2 * math.pi;
                      final color = palette[i % palette.length];
                      canvas
                        ..setFillColor(color)
                        ..moveTo(cx, cy)
                        ..lineTo(cx + r * math.cos(startAngle),
                                 cy + r * math.sin(startAngle));
                      const steps = 48;
                      for (var j = 1; j <= steps; j++) {
                        final a = startAngle + sweep * (j / steps);
                        canvas.lineTo(
                            cx + r * math.cos(a), cy + r * math.sin(a));
                      }
                      canvas
                        ..lineTo(cx, cy)
                        ..fillPath();
                      startAngle += sweep;
                    }
                    // White divider ring
                    canvas
                      ..setStrokeColor(PdfColors.white)
                      ..setLineWidth(1.2);
                    startAngle = -math.pi / 2;
                    for (var i = 0; i < entries.length; i++) {
                      final sweep = entries[i].value / total * 2 * math.pi;
                      canvas
                        ..moveTo(cx, cy)
                        ..lineTo(cx + r * math.cos(startAngle),
                                 cy + r * math.sin(startAngle))
                        ..strokePath();
                      startAngle += sweep;
                    }
                  },
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('Cost Breakdown',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _primary)),
                pw.SizedBox(height: 6),
                ...List.generate(entries.length, (i) {
                  final e = entries[i];
                  final pct = (e.value / total * 100).toStringAsFixed(1);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Row(children: [
                      pw.Container(
                          width: 10, height: 10,
                          color: palette[i % palette.length]),
                      pw.SizedBox(width: 5),
                      pw.Expanded(
                        child: pw.Text(
                          '${_titleCase(e.key.replaceAll('_', ' '))} — $pct%',
                          style: const pw.TextStyle(
                              fontSize: 8, color: _darkText),
                        ),
                      ),
                    ]),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _providerChart(List<Map<String, dynamic>> providers) {
    final maxCost = providers
        .map((p) => (p['total_cost'] as num).toDouble())
        .fold<double>(0, math.max) * 1.15;
    if (maxCost <= 0) return pw.SizedBox();

    return pw.Container(
      height: 170,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _softBorder, width: 0.4),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(children: [
        pw.Text('Provider Total Cost Comparison (Rs. \'000)',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: _primary)),
        pw.SizedBox(height: 6),
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: providers.map((p) {
              final v = (p['total_cost'] as num).toDouble();
              final h = v / maxCost;
              final isSelected = p['selected'] == true;
              return pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 1.5),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('${(v / 1000).round()}',
                          style: const pw.TextStyle(
                              fontSize: 6, color: _greyText)),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        height: math.max(2.0, 110 * h),
                        color: isSelected ? _orange : _blue,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        (p['provider'] as String).split(' ').first,
                        style: const pw.TextStyle(
                            fontSize: 6, color: _secondary),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Reusable primitives
  // ───────────────────────────────────────────────────────────────────────────
  pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 2),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 16,
                color: _primary,
                fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _subSection(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 12,
                color: _secondary,
                fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _divider() => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        height: 0.4,
        color: _softBorder,
      );

  pw.Widget _para(String html) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.RichText(
        text: _parseSimpleHtml(html),
        textAlign: pw.TextAlign.justify,
      ),
    );
  }

  pw.InlineSpan _parseSimpleHtml(String html) {
    // Decode &nbsp; and minimal entities.
    html = html
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&bull;', '•')
        .replaceAll('&amp;', '&');
    final spans = <pw.InlineSpan>[];
    final pattern = RegExp(r'<b>(.*?)</b>|<i>(.*?)</i>');
    int cursor = 0;
    for (final m in pattern.allMatches(html)) {
      if (m.start > cursor) {
        spans.add(pw.TextSpan(
          text: html.substring(cursor, m.start),
          style: const pw.TextStyle(fontSize: 10, color: _darkText),
        ));
      }
      if (m.group(1) != null) {
        spans.add(pw.TextSpan(
          text: m.group(1),
          style: pw.TextStyle(
              fontSize: 10,
              color: _darkText,
              fontWeight: pw.FontWeight.bold),
        ));
      } else if (m.group(2) != null) {
        spans.add(pw.TextSpan(
          text: m.group(2),
          style: pw.TextStyle(
              fontSize: 10,
              color: _darkText,
              fontStyle: pw.FontStyle.italic),
        ));
      }
      cursor = m.end;
    }
    if (cursor < html.length) {
      spans.add(pw.TextSpan(
        text: html.substring(cursor),
        style: const pw.TextStyle(fontSize: 10, color: _darkText),
      ));
    }
    return pw.TextSpan(children: spans);
  }

  pw.Widget _bullet(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('•  ',
                style: const pw.TextStyle(
                    fontSize: 10, color: _darkText)),
            pw.Expanded(child: _para(text)),
          ],
        ),
      );

  pw.Widget _kpiRow(List<List<String>> cards) {
    return pw.Row(
      children: cards
          .map((card) => pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 3),
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 12),
                    decoration: pw.BoxDecoration(
                      color: _kpiBg,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(
                          color: _softBorder, width: 0.4),
                    ),
                    child: pw.Column(children: [
                      pw.Text(card[0],
                          style: pw.TextStyle(
                              fontSize: 18,
                              color: _primary,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(card[1],
                          style: const pw.TextStyle(
                              fontSize: 9, color: _greyText)),
                    ]),
                  ),
                ),
              ))
          .toList(),
    );
  }

  pw.Widget _kvTable(List<List<String>> rows,
      {List<String> headers = const ['Parameter', 'Value']}) {
    return _styledTable(headers: headers, rows: rows, colFlex: const [3, 4]);
  }

  pw.Widget _styledTable({
    required List<String> headers,
    required List<List<String>> rows,
    required List<int> colFlex,
  }) {
    return pw.Table(
      columnWidths: {
        for (var i = 0; i < colFlex.length; i++)
          i: pw.FlexColumnWidth(colFlex[i].toDouble()),
      },
      border: pw.TableBorder.all(color: _softBorder, width: 0.3),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerBg),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5, horizontal: 5),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center),
                  ))
              .toList(),
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
                color: i.isOdd ? _altRowBg : PdfColors.white),
            children: rows[i]
                .map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 5),
                      child: pw.RichText(
                        text: _parseSimpleHtml(cell),
                        textAlign: pw.TextAlign.left,
                      ),
                    ))
                .toList(),
          ),
      ],
    );
  }

  // ── Formatting helpers ────────────────────────────────────────────────────
  String _rs(num v) => 'Rs. ${_numFmt(v.round())}';

  String _numFmt(num v) {
    final s = v.round().toString();
    // Indian numbering — lakh/crore grouping
    final neg = s.startsWith('-');
    final abs = neg ? s.substring(1) : s;
    if (abs.length <= 3) return neg ? '-$abs' : abs;
    final last3 = abs.substring(abs.length - 3);
    final rest = abs.substring(0, abs.length - 3);
    final rev = rest.split('').reversed.join();
    final chunks = <String>[];
    for (var i = 0; i < rev.length; i += 2) {
      chunks.add(rev.substring(i, math.min(i + 2, rev.length)));
    }
    final restFormatted = chunks.join(',').split('').reversed.join();
    final result = '$restFormatted,$last3';
    return neg ? '-$result' : result;
  }

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

// ─────────────────────────────────────────────────────────────────────────────
// Report context — precomputes every derived number once.
// ─────────────────────────────────────────────────────────────────────────────
class _ReportContext {
  final String reportId;
  final DateTime now;
  final Map<String, dynamic> staticData;

  final String userName;
  final String locationLine;
  final String dateLine;

  final double totalArea;
  final double usableArea;
  final int panelCount;
  final double systemKw;
  final int panelWatt;

  final double sunHours;
  final double annualKwh;
  final List<int> monthlyBreakdown;

  final int grossCost;
  final int netCost;
  final int centralSubsidy;
  final int stateSubsidy;
  final int totalSubsidy;
  final double subsidyPct;
  final int pricePerWatt;
  final Map<String, int> costBreakdown;

  final double tariff;
  final int annualSavings;
  final int lifetimeSavings;
  final List<int> cashflow;

  final double paybackYears;
  final double roiPct;

  final double co2PerYear;
  final double co2Lifetime;
  final int treesEquivalent;

  final String obstacleDesc;

  final Uint8List? arSnapshot; // AR camera capture embedded in the report
  final double? scanHeadingDeg; // compass heading at scan time

  _ReportContext({    required this.reportId,
    required this.now,
    required this.staticData,
    required this.userName,
    required this.locationLine,
    required this.dateLine,
    required this.totalArea,
    required this.usableArea,
    required this.panelCount,
    required this.systemKw,
    required this.panelWatt,
    required this.sunHours,
    required this.annualKwh,
    required this.monthlyBreakdown,
    required this.grossCost,
    required this.netCost,
    required this.centralSubsidy,
    required this.stateSubsidy,
    required this.totalSubsidy,
    required this.subsidyPct,
    required this.pricePerWatt,
    required this.costBreakdown,
    required this.tariff,
    required this.annualSavings,
    required this.lifetimeSavings,
    required this.cashflow,
    required this.paybackYears,
    required this.roiPct,
    required this.co2PerYear,
    required this.co2Lifetime,
    required this.treesEquivalent,
    required this.obstacleDesc,
    required this.arSnapshot,
    required this.scanHeadingDeg,
  });

  static _ReportContext from({
    required EnrichedScanResult scan,
    required UserSession session,
    required String reportId,
    required DateTime now,
    required Map<String, dynamic> staticData,
  }) {
    final tariff = session.avgTariffInr ?? 8.5;
    final panelWatt = scan.panelCount > 0
        ? ((scan.systemSizeKw * 1000) / scan.panelCount).round()
        : 550;
    final pricePerWatt = scan.systemSizeKw > 0
        ? (scan.estimatedCost / (scan.systemSizeKw * 1000)).round()
        : 54;

    final annualSavings = scan.annualSavingsInr.round();
    final lifetimeSavings = (scan.annualSavingsInr * 25).round();

    final cashflow = <int>[];
    var cum = -scan.netCost;
    cashflow.add(cum);
    for (var y = 1; y < 25; y++) {
      cum += annualSavings;
      cashflow.add(cum);
    }

    final roiPct = scan.netCost > 0
        ? ((lifetimeSavings - scan.netCost) / scan.netCost) * 100
        : 0.0;

    final co2PerYear = scan.annualKwh * 0.000820;
    final co2Lifetime = co2PerYear * 25;
    final trees = (co2PerYear * 16).round();

    final subsidyPct = scan.estimatedCost > 0
        ? (scan.totalSubsidy / scan.estimatedCost) * 100
        : 0.0;

    // Latitude-aware seasonal curve — replaces the previous hardcoded India
    // curve. Uses the scan latitude; falls back to the 20°N India mean when
    // latitude is unknown. Monsoon attenuation (Jun–Aug) is applied for India.
    final lat = scan.lat ?? 20.0;
    final curve = monthlyGenerationProfile(lat, indiaMonsoonAdjust: true);
    final avg = scan.annualKwh / 12;
    final monthly = curve.map((k) => (avg * k).round()).toList();

    final cost = scan.estimatedCost;
    final breakdown = <String, int>{
      'solar_panels'           : (cost * 0.61).round(),
      'inverter'               : (cost * 0.185).round(),
      'mounting_structure'     : (cost * 0.083).round(),
      'wiring_and_accessories' : (cost * 0.056).round(),
      'installation_labor'     : (cost * 0.047).round(),
      'net_metering_charges'   : (cost * 0.019).round(),
    };

    final city = session.city ?? '';
    final stateName = scan.stateDisplayName.isNotEmpty
        ? scan.stateDisplayName
        : (session.stateKey ?? '');
    final loc = [city, stateName].where((s) => s.isNotEmpty).join(', ');

    const months = ['January','February','March','April','May','June',
                    'July','August','September','October','November','December'];
    final dateLine = '${now.day} ${months[now.month - 1]} ${now.year}';

    final obstacleDesc = scan.detectedObstacles.isEmpty
        ? 'No major obstacles detected in AR scan'
        : scan.detectedObstacles
            .map((o) => (o as dynamic).label?.toString() ?? 'obstacle')
            .toSet()
            .join(', ');

    return _ReportContext(
      reportId: reportId,
      now: now,
      staticData: staticData,
      userName: session.name ?? 'SolarMitra User',
      locationLine: loc.isEmpty ? 'India' : loc,
      dateLine: dateLine,
      totalArea: scan.totalAreaM2,
      usableArea: scan.usableAreaM2,
      panelCount: scan.panelCount,
      systemKw: scan.systemSizeKw,
      panelWatt: panelWatt,
      sunHours: scan.peakSunHours,
      annualKwh: scan.annualKwh,
      monthlyBreakdown: monthly,
      grossCost: scan.estimatedCost,
      netCost: scan.netCost,
      centralSubsidy: scan.centralSubsidy,
      stateSubsidy: scan.stateSubsidy,
      totalSubsidy: scan.totalSubsidy,
      subsidyPct: subsidyPct,
      pricePerWatt: pricePerWatt,
      costBreakdown: breakdown,
      tariff: tariff,
      annualSavings: annualSavings,
      lifetimeSavings: lifetimeSavings,
      cashflow: cashflow,
      paybackYears: scan.paybackYears,
      roiPct: roiPct,
      co2PerYear: co2PerYear,
      co2Lifetime: co2Lifetime,
      treesEquivalent: trees,
      obstacleDesc: obstacleDesc,
      arSnapshot: scan.captureJpeg,
      scanHeadingDeg: scan.headingDeg,
    );
  }
}
