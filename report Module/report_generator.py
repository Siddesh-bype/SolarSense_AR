"""
SolarSense AR - Report Module
Generates a professional PDF report from solar estimation data (data.json).
"""

import json
import os
import sys
from datetime import datetime

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm, cm
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, Image, HRFlowable, KeepTogether, CondPageBreak
)
from reportlab.graphics.shapes import Drawing, Rect, String, Line
from reportlab.graphics.charts.lineplots import LinePlot
from reportlab.graphics.charts.barcharts import VerticalBarChart
from reportlab.graphics.widgets.markers import makeMarker

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

from ai_content import generate_all_paragraphs


# ---------------------------------------------------------------------------
# Color palette  — muted, professional, report-grade
# ---------------------------------------------------------------------------
PRIMARY = colors.HexColor("#2C3E50")       # dark slate
SECONDARY = colors.HexColor("#5D6D7E")     # steel grey
ACCENT = colors.HexColor("#7F8C8D")        # warm grey (dividers, subtle marks)
DARK_TEXT = colors.HexColor("#2C3E50")
GREY_TEXT = colors.HexColor("#717D7E")
WHITE = colors.white
TABLE_HEADER_BG = colors.HexColor("#34495E")   # charcoal header
TABLE_ALT_ROW = colors.HexColor("#F4F6F7")     # barely-there grey
KPI_BG = colors.HexColor("#F8F9FA")            # near-white card bg
KPI_BORDER = colors.HexColor("#D5D8DC")        # soft border


# ---------------------------------------------------------------------------
# Custom styles
# ---------------------------------------------------------------------------
def build_styles():
    ss = getSampleStyleSheet()

    ss.add(ParagraphStyle(
        "SectionTitle", parent=ss["Heading1"],
        fontSize=16, textColor=PRIMARY, spaceAfter=6*mm,
        spaceBefore=8*mm, leading=20,
    ))
    ss.add(ParagraphStyle(
        "SubSection", parent=ss["Heading2"],
        fontSize=13, textColor=SECONDARY, spaceAfter=4*mm,
        spaceBefore=4*mm, leading=16,
    ))
    ss.add(ParagraphStyle(
        "BodyText2", parent=ss["BodyText"],
        fontSize=10, textColor=DARK_TEXT, leading=14,
        alignment=TA_JUSTIFY, spaceAfter=3*mm,
    ))
    ss.add(ParagraphStyle(
        "SmallGrey", parent=ss["BodyText"],
        fontSize=8, textColor=GREY_TEXT, leading=10,
        alignment=TA_JUSTIFY,
    ))
    ss.add(ParagraphStyle(
        "CoverTitle", parent=ss["Title"],
        fontSize=30, textColor=WHITE, alignment=TA_CENTER,
        spaceAfter=5*mm, leading=36,
    ))
    ss.add(ParagraphStyle(
        "CoverSub", parent=ss["Normal"],
        fontSize=14, textColor=colors.HexColor("#C8E6C9"),
        alignment=TA_CENTER, spaceAfter=3*mm, leading=18,
    ))
    ss.add(ParagraphStyle(
        "KPIValue", parent=ss["Normal"],
        fontSize=20, textColor=PRIMARY, alignment=TA_CENTER,
        leading=24, fontName="Helvetica-Bold",
    ))
    ss.add(ParagraphStyle(
        "KPILabel", parent=ss["Normal"],
        fontSize=9, textColor=GREY_TEXT, alignment=TA_CENTER,
        leading=12,
    ))
    return ss


# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------
def rupees(val):
    """Format number as Indian Rupees."""
    val = int(val)
    s = f"{val:,}"
    return f"Rs. {s}"


def section_divider():
    return HRFlowable(
        width="100%", thickness=0.4, color=colors.HexColor("#D5D8DC"),
        spaceBefore=2*mm, spaceAfter=4*mm,
    )


def kpi_card(value_text, label_text, styles):
    """Return a small table that looks like a KPI card."""
    data = [
        [Paragraph(value_text, styles["KPIValue"])],
        [Paragraph(label_text, styles["KPILabel"])],
    ]
    t = Table(data, colWidths=[55*mm], rowHeights=[12*mm, 8*mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), KPI_BG),
        ("BOX", (0, 0), (-1, -1), 0.4, KPI_BORDER),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("TOPPADDING", (0, 0), (-1, 0), 4*mm),
        ("BOTTOMPADDING", (0, -1), (-1, -1), 3*mm),
        ("ROUNDEDCORNERS", [3, 3, 3, 3]),
    ]))
    return t


def styled_table(headers, rows, col_widths=None):
    """Generic styled table with header row."""
    header_row = [Paragraph(f'<b>{h}</b>', ParagraphStyle(
        "th", fontSize=9, textColor=WHITE, alignment=TA_CENTER,
        fontName="Helvetica-Bold", leading=11,
    )) for h in headers]

    body_style = ParagraphStyle("td", fontSize=9, textColor=DARK_TEXT,
                                alignment=TA_CENTER, leading=11)
    body_rows = []
    for row in rows:
        body_rows.append([Paragraph(str(c), body_style) for c in row])

    data = [header_row] + body_rows
    t = Table(data, colWidths=col_widths, repeatRows=1)

    style_cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), TABLE_HEADER_BG),
        ("TEXTCOLOR", (0, 0), (-1, 0), WHITE),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, 0), 9),
        ("BOTTOMPADDING", (0, 0), (-1, 0), 2*mm),
        ("TOPPADDING", (0, 0), (-1, 0), 2*mm),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("GRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#D5D8DC")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [WHITE, TABLE_ALT_ROW]),
        ("TOPPADDING", (0, 1), (-1, -1), 1.2*mm),
        ("BOTTOMPADDING", (0, 1), (-1, -1), 1.2*mm),
    ]
    t.setStyle(TableStyle(style_cmds))
    return t


# ---------------------------------------------------------------------------
# Chart generators (matplotlib -> PNG -> reportlab Image)
# ---------------------------------------------------------------------------
def _apply_clean_style(ax):
    """Shared minimal chart styling."""
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color("#BDC3C7")
    ax.spines["bottom"].set_color("#BDC3C7")
    ax.tick_params(colors="#5D6D7E", labelsize=8)
    ax.yaxis.label.set_color("#5D6D7E")
    ax.xaxis.label.set_color("#5D6D7E")


def generate_monthly_energy_chart(monthly_data, output_dir):
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    fig, ax = plt.subplots(figsize=(6.5, 3))
    ax.bar(months, monthly_data, color="#F39C12", edgecolor="#E67E22", linewidth=0.5)
    ax.set_ylabel("Units (kWh)", fontsize=9)
    ax.set_title("Monthly Energy Generation Estimate", fontsize=11, fontweight="bold",
                 color="#2C3E50")
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{int(x)}"))
    _apply_clean_style(ax)
    ax.grid(axis="y", color="#EAECEE", linewidth=0.5)
    ax.set_axisbelow(True)
    plt.tight_layout()
    path = os.path.join(output_dir, "chart_monthly_energy.png")
    fig.savefig(path, dpi=150, facecolor="white")
    plt.close(fig)
    return path


def generate_cashflow_chart(cashflow, output_dir):
    years = list(range(1, len(cashflow) + 1))
    fig, ax = plt.subplots(figsize=(6.5, 3.2))
    bar_colors = ["#E74C3C" if v < 0 else "#27AE60" for v in cashflow]
    ax.bar(years, [v / 1000 for v in cashflow], color=bar_colors, edgecolor="none")
    ax.axhline(0, color="#2C3E50", linewidth=0.7, linestyle="--")
    ax.set_xlabel("Year", fontsize=9)
    ax.set_ylabel("Cumulative Cash Flow (Rs. '000)", fontsize=9)
    ax.set_title("Cumulative Cash Flow Over 25 Years", fontsize=11,
                 fontweight="bold", color="#2C3E50")
    _apply_clean_style(ax)
    ax.grid(axis="y", color="#EAECEE", linewidth=0.5)
    ax.set_axisbelow(True)
    plt.tight_layout()
    path = os.path.join(output_dir, "chart_cashflow.png")
    fig.savefig(path, dpi=150, facecolor="white")
    plt.close(fig)
    return path


def generate_cost_pie_chart(breakdown, output_dir):
    labels = list(breakdown.keys())
    values = list(breakdown.values())
    display_labels = [l.replace("_", " ").title() for l in labels]

    fig, ax = plt.subplots(figsize=(5, 3.5))
    pastel = ["#AED6F1", "#A9DFBF", "#F9E79F", "#F5CBA7", "#D7BDE2", "#D5DBDB"]
    wedges, texts, autotexts = ax.pie(
        values, labels=display_labels, autopct="%1.1f%%",
        colors=pastel[:len(values)], startangle=140,
        textprops={"fontsize": 8, "color": "#2C3E50"},
        wedgeprops={"edgecolor": "white", "linewidth": 1},
    )
    for at in autotexts:
        at.set_fontsize(7)
        at.set_color("#2C3E50")
    ax.set_title("Cost Breakdown", fontsize=11, fontweight="bold", color="#2C3E50")
    plt.tight_layout()
    path = os.path.join(output_dir, "chart_cost_pie.png")
    fig.savefig(path, dpi=150, facecolor="white")
    plt.close(fig)
    return path


def generate_provider_chart(providers, output_dir):
    names = [p["provider"] for p in providers]
    costs = [p["total_cost"] / 1000 for p in providers]
    paybacks = [p["payback_years"] for p in providers]

    fig, ax1 = plt.subplots(figsize=(6, 3.2))
    x = range(len(names))
    bar_colors = ["#2980B9" if not p.get("selected") else "#F39C12" for p in providers]
    ax1.bar(x, costs, color=bar_colors, edgecolor="white", width=0.5, linewidth=0.5)
    ax1.set_ylabel("Total Cost (Rs. '000)", fontsize=9)
    ax1.set_xticks(list(x))
    ax1.set_xticklabels(names, fontsize=7, rotation=30, ha="right")

    ax2 = ax1.twinx()
    ax2.plot(list(x), paybacks, "D-", color="#E74C3C", markersize=5, linewidth=1.4)
    ax2.set_ylabel("Payback (years)", fontsize=9, color="#E74C3C")
    ax2.tick_params(colors="#E74C3C", labelsize=8)
    ax2.spines["right"].set_color("#E74C3C")

    ax1.set_title("Provider Comparison", fontsize=11, fontweight="bold", color="#2C3E50")
    _apply_clean_style(ax1)
    ax2.spines["top"].set_visible(False)
    ax1.grid(axis="y", color="#EAECEE", linewidth=0.5)
    ax1.set_axisbelow(True)
    plt.tight_layout()
    path = os.path.join(output_dir, "chart_providers.png")
    fig.savefig(path, dpi=150, facecolor="white")
    plt.close(fig)
    return path


# ---------------------------------------------------------------------------
# Header / Footer
# ---------------------------------------------------------------------------
# Path to cover background image
_COVER_BG = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "assets", "front_page.png")

# Store cover data so the first-page callback can render it
_cover_info = {}


def first_page(canvas, doc):
    """Cover page: full-bleed background image + overlay text, no header/footer."""
    canvas.saveState()
    page_w, page_h = A4

    # Draw background image edge-to-edge
    if os.path.exists(_COVER_BG):
        canvas.drawImage(_COVER_BG, 0, 0, width=page_w, height=page_h,
                         preserveAspectRatio=False, mask="auto")

    # Semi-transparent dark overlay for text readability
    canvas.setFillColor(colors.Color(0.17, 0.24, 0.31, alpha=0.70))  # slate tint
    canvas.rect(0, 0, page_w, page_h, fill=1, stroke=0)

    # ---------- Text overlay ----------
    cx = page_w / 2
    info = _cover_info

    # Project name
    canvas.setFont("Helvetica-Bold", 36)
    canvas.setFillColor(WHITE)
    canvas.drawCentredString(cx, page_h - 160, info.get("project_name", "SolarSense AR"))

    # Subtitle
    canvas.setFont("Helvetica", 16)
    canvas.setFillColor(colors.HexColor("#D5D8DC"))
    canvas.drawCentredString(cx, page_h - 195, "Solar Assessment Report")

    # Horizontal accent line — thin, white
    canvas.setStrokeColor(colors.HexColor("#AEB6BF"))
    canvas.setLineWidth(0.8)
    canvas.line(cx - 50*mm, page_h - 215, cx + 50*mm, page_h - 215)

    # User details
    y = page_h - 260
    canvas.setFont("Helvetica", 14)
    canvas.setFillColor(WHITE)
    canvas.drawCentredString(cx, y, f'Prepared for: {info.get("user_name", "")}')

    y -= 28
    canvas.setFont("Helvetica", 13)
    canvas.setFillColor(colors.HexColor("#D5D8DC"))
    canvas.drawCentredString(cx, y, f'Location: {info.get("location", "")}')

    y -= 26
    canvas.drawCentredString(cx, y, f'Date: {info.get("date", "")}')

    y -= 26
    canvas.setFont("Helvetica", 11)
    canvas.setFillColor(colors.HexColor("#AEB6BF"))
    canvas.drawCentredString(cx, y, f'Report ID: {info.get("report_id", "")}')

    # Bottom branding
    canvas.setFont("Helvetica", 9)
    canvas.setFillColor(colors.HexColor("#AEB6BF"))
    canvas.drawCentredString(cx, 25*mm, info.get("generated_by", ""))

    canvas.restoreState()


def later_pages(canvas, doc):
    """Standard header + footer for pages 2 onward."""
    canvas.saveState()
    # Header line
    canvas.setStrokeColor(PRIMARY)
    canvas.setLineWidth(1)
    canvas.line(15*mm, A4[1] - 12*mm, A4[0] - 15*mm, A4[1] - 12*mm)
    canvas.setFont("Helvetica-Bold", 8)
    canvas.setFillColor(PRIMARY)
    canvas.drawString(15*mm, A4[1] - 10*mm, "SolarSense AR")
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(GREY_TEXT)
    canvas.drawRightString(A4[0] - 15*mm, A4[1] - 10*mm, "Solar Assessment Report")

    # Footer
    canvas.setFont("Helvetica", 7)
    canvas.setFillColor(GREY_TEXT)
    canvas.drawString(15*mm, 10*mm,
                      "Generated by SolarSense Report Engine  |  Confidential")
    canvas.drawRightString(A4[0] - 15*mm, 10*mm, f"Page {doc.page}")
    canvas.restoreState()


# ---------------------------------------------------------------------------
# Section builders
# ---------------------------------------------------------------------------
def build_cover_page(data, styles):
    """Section 1 - Cover Page.
    All cover visuals are drawn by the first_page() canvas callback.
    This just populates _cover_info and emits a PageBreak so the
    background image fills page 1 entirely.
    """
    global _cover_info
    user = data["user"]
    meta = data["report_metadata"]
    ts = datetime.fromisoformat(data["timestamp"].replace("Z", "+00:00"))

    _cover_info = {
        "project_name": meta["project_name"],
        "user_name": user["name"],
        "location": f'{user["location"]["city"]}, {user["location"]["state"]}',
        "date": ts.strftime("%d %B %Y"),
        "report_id": data["report_id"],
        "generated_by": f'{meta["generated_by"]} | v{meta["version"]}',
    }

    # Empty content — the canvas callback draws everything on the background.
    # A tiny spacer + PageBreak ensures page 1 exists and we move to page 2.
    return [Spacer(1, 1), PageBreak()]


def build_executive_summary(data, styles, ai_paragraphs):
    """Section 2 - Executive Summary"""
    elements = []
    elements.append(Paragraph("1. Executive Summary", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("executive_summary", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    fin = data["financial_analysis"]
    roi = data["roi_analysis"]
    se = data["solar_estimation"]

    cards = [
        kpi_card(f"{se['system_size_kw']} kW", "System Size", styles),
        kpi_card(rupees(fin["cost"]["total_installation_cost"]), "Total Cost", styles),
        kpi_card(rupees(fin["subsidy"]["subsidy_amount"]), "Govt. Subsidy", styles),
    ]
    row1 = Table([cards], colWidths=[60*mm, 60*mm, 60*mm])
    row1.setStyle(TableStyle([
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))
    elements.append(row1)
    elements.append(Spacer(1, 4*mm))

    cards2 = [
        kpi_card(rupees(fin["net_cost"]), "Net Payable", styles),
        kpi_card(f"{roi['payback_period_years']} yrs", "Payback Period", styles),
        kpi_card(f"{roi['roi_percentage']}%", "25-Year ROI", styles),
    ]
    row2 = Table([cards2], colWidths=[60*mm, 60*mm, 60*mm])
    row2.setStyle(TableStyle([
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))
    elements.append(row2)
    elements.append(Spacer(1, 6*mm))
    return elements


def build_rooftop_analysis(data, styles, ai_paragraphs):
    """Section 3 - Rooftop Analysis"""
    elements = []
    elements.append(Paragraph("2. Rooftop Analysis", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("rooftop_analysis", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    roof = data["input_data"]["rooftop"]
    rows = [
        ["Total Rooftop Area", f'{roof["total_area_sqm"]} sq.m'],
        ["Usable Area (after obstacles)", f'{roof["usable_area_sqm"]} sq.m'],
        ["Obstacle Area", f'{roof["obstacles_area_sqm"]} sq.m'],
        ["Obstacles Identified", roof.get("obstacle_details", "N/A")],
    ]
    panel = data["solar_estimation"]["panel"]
    rows.append(["Panels That Fit", f'{panel["number_of_panels"]} panels '
                 f'({panel["area_per_panel_sqm"]} sq.m each)'])

    t = styled_table(["Parameter", "Value"], rows, col_widths=[90*mm, 80*mm])
    elements.append(t)
    elements.append(Spacer(1, 4*mm))

    layout_desc = data["solar_estimation"].get("layout_description", "")
    if layout_desc:
        elements.append(Paragraph(f"<b>Panel Layout:</b> {layout_desc}",
                                  styles["BodyText2"]))
    elements.append(Spacer(1, 4*mm))
    return elements


def build_system_design(data, styles, ai_paragraphs):
    """Section 4 - Solar System Design"""
    elements = []
    elements.append(Paragraph("3. Solar System Design", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("system_design", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    se = data["solar_estimation"]
    panel = se["panel"]
    inv = se.get("inverter", {})
    rows = [
        ["System Size", f'{se["system_size_kw"]} kW'],
        ["Number of Panels", str(panel["number_of_panels"])],
        ["Panel Model", panel.get("panel_model", "N/A")],
        ["Panel Wattage", f'{panel["watt_per_panel"]} W'],
        ["Panel Type", panel.get("panel_type", "N/A")],
        ["Inverter", f'{inv.get("brand", "N/A")} {inv.get("capacity_kw", "")} kW '
                     f'({inv.get("type", "")})'],
        ["System Efficiency", f'{se["efficiency"] * 100:.0f}%'],
        ["Expected Lifetime", f'{se.get("system_lifetime_years", 25)} years'],
        ["Annual Degradation", f'{se.get("degradation_rate_per_year", 0.005) * 100:.1f}%'],
    ]
    t = styled_table(["Specification", "Detail"], rows, col_widths=[90*mm, 80*mm])
    elements.append(t)
    elements.append(Spacer(1, 4*mm))
    return elements


def build_energy_estimate(data, styles, output_dir, ai_paragraphs):
    """Section 5 - Energy Generation Estimate"""
    elements = []
    elements.append(Paragraph("4. Energy Generation Estimate", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("energy_estimate", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    eo = data["energy_output"]
    rows = [
        ["Monthly Generation (avg)", f'{eo["monthly_units_generated"]} kWh'],
        ["Annual Generation", f'{eo["annual_units_generated"]} kWh'],
        ["Performance Ratio", f'{eo["performance_ratio"] * 100:.0f}%'],
        ["Avg Sun Hours / Day", f'{eo.get("average_sun_hours_per_day", "N/A")} hrs'],
    ]
    t = styled_table(["Metric", "Value"], rows, col_widths=[90*mm, 80*mm])
    elements.append(t)
    elements.append(Spacer(1, 4*mm))

    monthly = eo.get("monthly_breakdown")
    if monthly:
        chart_path = generate_monthly_energy_chart(monthly, output_dir)
        elements.append(Image(chart_path, width=160*mm, height=74*mm))
        elements.append(Spacer(1, 4*mm))

    return elements


def build_cost_breakdown(data, styles, output_dir, ai_paragraphs):
    """Section 6 - Cost Breakdown"""
    elements = []
    elements.append(Paragraph("5. Cost Breakdown", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("cost_breakdown", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    cost = data["financial_analysis"]["cost"]
    elements.append(Paragraph(
        f'<b>Price per Watt:</b> Rs. {cost["price_per_watt"]}/W &nbsp;&nbsp;|&nbsp;&nbsp;'
        f'<b>Total Installation Cost:</b> {rupees(cost["total_installation_cost"])}',
        styles["BodyText2"],
    ))

    breakdown = cost.get("component_breakdown", {})
    if breakdown:
        rows = [[k.replace("_", " ").title(), rupees(v)]
                for k, v in breakdown.items()]
        rows.append(["Total", rupees(cost["total_installation_cost"])])
        t = styled_table(["Component", "Cost"], rows, col_widths=[100*mm, 70*mm])
        elements.append(t)
        elements.append(Spacer(1, 4*mm))

        chart_path = generate_cost_pie_chart(breakdown, output_dir)
        elements.append(Image(chart_path, width=130*mm, height=90*mm))

    elements.append(Spacer(1, 4*mm))
    return elements


def build_subsidy_details(data, styles, ai_paragraphs):
    """Section 7 - Government Subsidy Details"""
    elements = []
    elements.append(Paragraph("6. Government Subsidy Details", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("subsidy_details", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    sub = data["financial_analysis"]["subsidy"]
    fin = data["financial_analysis"]
    rows = [
        ["Scheme Name", sub["scheme"]],
        ["Eligible", "Yes" if sub["eligible"] else "No"],
        ["Subsidy Amount", rupees(sub["subsidy_amount"])],
        ["Subsidy as % of Cost", f'{sub.get("subsidy_percentage", "N/A")}%'],
        ["Subsidy Calculation", sub.get("subsidy_detail", "N/A")],
        ["Final Cost After Subsidy", rupees(fin["net_cost"])],
    ]
    t = styled_table(["Detail", "Value"], rows, col_widths=[90*mm, 80*mm])
    elements.append(t)
    elements.append(Spacer(1, 4*mm))
    return elements


def build_subsidy_scheme_guide(data, styles, ai_paragraphs):
    """Section 7b - PM Surya Ghar Scheme Complete Guide"""
    guide = data.get("subsidy_scheme_guide")
    if not guide:
        return []

    elements = []
    elements.append(Paragraph("8. PM Surya Ghar Yojana — Complete Guide",
                              styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("subsidy_scheme_guide", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    # Scheme overview
    elements.append(Paragraph(
        f'<b>Official Portal:</b> {guide["official_website"]} &nbsp;|&nbsp; '
        f'<b>Helpline:</b> {guide["helpline"]}', styles["BodyText2"]))
    elements.append(Paragraph(
        f'<b>Launched:</b> {guide["launched"]} &nbsp;|&nbsp; '
        f'<b>Total Outlay:</b> Rs. {guide["total_outlay_crore"]:,} Crore &nbsp;|&nbsp; '
        f'<b>Target:</b> {guide["target"]}', styles["BodyText2"]))
    elements.append(Spacer(1, 3*mm))

    # --- Subsidy Slabs Table ---
    elements.append(Paragraph("<b>Subsidy Structure (Central Financial Assistance)</b>",
                              styles["SubSection"]))
    slab_headers = ["System Capacity", "Benchmark Cost", "Subsidy %",
                    "Subsidy Amount", "Your Net Cost"]
    slab_rows = []
    for s in guide["subsidy_slabs"]:
        slab_rows.append([
            s["capacity"],
            f'Rs. {s["benchmark_cost"]}',
            s["subsidy_percent"],
            rupees(s["subsidy_amount"]),
            f'Rs. {s["net_cost_range"]}',
        ])
    t = styled_table(slab_headers, slab_rows,
                     col_widths=[30*mm, 34*mm, 24*mm, 30*mm, 34*mm])
    elements.append(t)
    elements.append(Spacer(1, 3*mm))

    # --- How subsidy is calculated ---
    elements.append(Paragraph("<b>How Subsidy is Calculated</b>", styles["SubSection"]))
    for i, step in enumerate(guide["calculation_formula"], 1):
        elements.append(Paragraph(f"&nbsp;&nbsp;{i}. {step}", styles["BodyText2"]))
    elements.append(Spacer(1, 3*mm))

    # --- Eligibility ---
    elements.append(Paragraph("<b>Eligibility Criteria</b>", styles["SubSection"]))
    for item in guide["eligibility"]:
        elements.append(Paragraph(f"&nbsp;&nbsp;&bull; {item}", styles["BodyText2"]))
    elements.append(Spacer(1, 3*mm))

    # --- Required Documents ---
    elements.append(Paragraph("<b>Required Documents</b>", styles["SubSection"]))
    doc_headers = ["Document", "Purpose"]
    doc_rows = [[d["document"], d["purpose"]] for d in guide["required_documents"]]
    t = styled_table(doc_headers, doc_rows, col_widths=[70*mm, 100*mm])
    elements.append(t)
    elements.append(Spacer(1, 3*mm))

    # --- Step-by-step application ---
    elements.append(Paragraph("<b>Step-by-Step Application Process</b>",
                              styles["SubSection"]))
    for i, step in enumerate(guide["application_steps"], 1):
        elements.append(Paragraph(f"&nbsp;&nbsp;<b>Step {i}:</b> {step}",
                                  styles["BodyText2"]))
    elements.append(Spacer(1, 3*mm))

    # --- Key Benefits ---
    elements.append(Paragraph("<b>Key Benefits</b>", styles["SubSection"]))
    ben_headers = ["Benefit", "Details"]
    ben_rows = [[b["benefit"], b["details"]] for b in guide["key_benefits"]]
    t = styled_table(ben_headers, ben_rows, col_widths=[45*mm, 125*mm])
    elements.append(t)
    elements.append(Spacer(1, 3*mm))

    # --- State-wise additional subsidies ---
    user_state = data["user"]["location"]["state"]
    elements.append(Paragraph(
        f'<b>State-Wise Additional Subsidies</b> (on top of Central)',
        styles["SubSection"]))
    state_headers = ["State", "Additional Subsidy", "Portal", "Notes"]
    state_rows = []
    for s in guide["state_subsidies"]:
        row = [s["state"], s["additional_subsidy"], s["portal"], s["notes"]]
        state_rows.append(row)
    t = styled_table(state_headers, state_rows,
                     col_widths=[30*mm, 40*mm, 40*mm, 52*mm])
    elements.append(t)
    elements.append(Spacer(1, 3*mm))

    # --- Financing Options ---
    elements.append(Paragraph("<b>Financing Options</b>", styles["SubSection"]))
    fin_headers = ["Bank / Lender", "Loan Type", "Interest Rate", "Max Amount"]
    fin_rows = []
    for f in guide["financing_options"]:
        fin_rows.append([
            f["bank"], f["loan_type"], f["interest_rate"], rupees(f["max_amount"])
        ])
    t = styled_table(fin_headers, fin_rows,
                     col_widths=[42*mm, 38*mm, 35*mm, 35*mm])
    elements.append(t)
    elements.append(Spacer(1, 3*mm))

    # --- Important Rules ---
    elements.append(Paragraph("<b>Important Rules & Restrictions</b>",
                              styles["SubSection"]))
    for rule in guide["important_rules"]:
        elements.append(Paragraph(f"&nbsp;&nbsp;&bull; {rule}", styles["BodyText2"]))
    elements.append(Spacer(1, 3*mm))

    # --- Important Links ---
    elements.append(Paragraph("<b>Important Contacts & Links</b>", styles["SubSection"]))
    link_headers = ["Resource", "Link / Contact", "Purpose"]
    link_rows = [[l["resource"], l["link"], l["purpose"]]
                 for l in guide["important_links"]]
    t = styled_table(link_headers, link_rows, col_widths=[40*mm, 55*mm, 65*mm])
    elements.append(t)
    elements.append(Spacer(1, 4*mm))

    return elements


def build_savings_analysis(data, styles, ai_paragraphs):
    """Section 8 - Savings Analysis"""
    elements = []
    elements.append(Paragraph("9. Savings Analysis", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("savings_analysis", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    sav = data["savings"]
    rows = [
        ["Monthly Savings", rupees(sav["monthly_savings"])],
        ["Annual Savings", rupees(sav["annual_savings"])],
        ["25-Year Lifetime Savings", rupees(sav["lifetime_savings_25yr"])],
    ]
    t = styled_table(["Period", "Savings"], rows, col_widths=[90*mm, 80*mm])
    elements.append(t)
    elements.append(Spacer(1, 4*mm))
    return elements


def build_roi_analysis(data, styles, output_dir, ai_paragraphs):
    """Section 9 - ROI & Payback Analysis"""
    elements = []
    elements.append(Paragraph("10. ROI & Payback Analysis", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("roi_analysis", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    roi = data["roi_analysis"]
    rows = [
        ["Payback Period", f'{roi["payback_period_years"]} years'],
        ["ROI (25-year)", f'{roi["roi_percentage"]}%'],
        ["Break-even Year", f'Year {roi["breakeven_year"]}'],
    ]
    t = styled_table(["Metric", "Value"], rows, col_widths=[90*mm, 80*mm])
    elements.append(t)
    elements.append(Spacer(1, 4*mm))

    cashflow = data["savings"].get("yearly_cashflow")
    if cashflow:
        chart_path = generate_cashflow_chart(cashflow, output_dir)
        elements.append(Image(chart_path, width=160*mm, height=78*mm))

    elements.append(Spacer(1, 4*mm))
    return elements


def build_provider_comparison(data, styles, output_dir, ai_paragraphs):
    """Section 10 - Provider Comparison"""
    elements = []
    elements.append(Paragraph("11. Provider Comparison", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("provider_comparison", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    providers = data["provider_comparison"]
    selected = data["input_data"]["provider_selected"]
    elements.append(Paragraph(
        f'<b>Selected Provider:</b> {selected} &nbsp;&nbsp;|&nbsp;&nbsp;'
        f'<b>All providers are ALMM-listed</b> (eligible for PM Surya Ghar subsidy)',
        styles["BodyText2"],
    ))

    headers = ["Provider", "Rs./W Range", "3kW Cost", "Efficiency",
               "Warranty", "Rating"]
    rows = []
    for p in providers:
        marker = " *" if p.get("selected") else ""
        scale = p.get("rating_scale", 10)
        rows.append([
            p["provider"] + marker,
            f'Rs. {p.get("price_per_watt_range", p["price_per_watt"])}',
            rupees(p["total_cost"]),
            p.get("best_efficiency", "N/A"),
            f'{p["warranty_years"]} yrs',
            f'{p["rating"]}/{scale}',
        ])
    t = styled_table(headers, rows,
                     col_widths=[32*mm, 28*mm, 28*mm, 30*mm, 22*mm, 22*mm])
    elements.append(t)
    elements.append(Spacer(1, 4*mm))

    chart_path = generate_provider_chart(providers, output_dir)
    elements.append(Image(chart_path, width=150*mm, height=78*mm))
    elements.append(Spacer(1, 4*mm))
    return elements


def build_environmental_impact(data, styles, ai_paragraphs):
    """Section 11 - Environmental Impact"""
    elements = []
    elements.append(Paragraph("12. Environmental Impact", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("environmental_impact", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    env = data["environmental_impact"]
    cards = [
        kpi_card(f'{env["co2_savings_per_year_tons"]} tons/yr', "CO2 Reduction", styles),
        kpi_card(str(env["trees_equivalent"]), "Trees Equivalent", styles),
        kpi_card(f'{env.get("co2_savings_lifetime_tons", "N/A")} tons',
                 "25-Year CO2 Saved", styles),
    ]
    row = Table([cards], colWidths=[60*mm, 60*mm, 60*mm])
    row.setStyle(TableStyle([
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))
    elements.append(row)
    elements.append(Spacer(1, 6*mm))

    elements.append(Paragraph(
        f'Your solar system offsets approximately <b>{env["co2_savings_per_year_tons"]} '
        f'tons of CO2 every year</b>, equivalent to planting '
        f'<b>{env["trees_equivalent"]} trees</b>. Over 25 years, this adds up to '
        f'<b>{env.get("co2_savings_lifetime_tons", "N/A")} tons</b> of carbon avoided.',
        styles["BodyText2"],
    ))
    elements.append(Spacer(1, 4*mm))
    return elements


def build_visual_output(data, styles, ai_paragraphs):
    """Section 12 - Visual Output"""
    elements = []
    elements.append(Paragraph("13. Visual Output", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("visual_output", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    base_dir = os.path.dirname(__file__)
    ar_path = data["visual_data"].get("ar_snapshot_path", "")
    layout_path = data["visual_data"].get("panel_layout_path", "")

    full_ar = os.path.join(base_dir, ar_path)
    full_layout = os.path.join(base_dir, layout_path)

    if ar_path and os.path.exists(full_ar):
        elements.append(Paragraph("AR Rooftop Snapshot", styles["SubSection"]))
        elements.append(Image(full_ar, width=150*mm, height=85*mm))
        elements.append(Spacer(1, 4*mm))
    else:
        elements.append(Paragraph(
            '<i>AR rooftop snapshot will be embedded here once captured from the '
            'mobile application.</i>', styles["SmallGrey"],
        ))
        elements.append(Spacer(1, 4*mm))

    if layout_path and os.path.exists(full_layout):
        elements.append(Paragraph("Panel Placement Visualization", styles["SubSection"]))
        elements.append(Image(full_layout, width=150*mm, height=85*mm))
        elements.append(Spacer(1, 4*mm))
    else:
        elements.append(Paragraph(
            '<i>Panel layout visualization will be embedded here once generated '
            'from the AR module.</i>', styles["SmallGrey"],
        ))
        elements.append(Spacer(1, 4*mm))

    return elements


def build_assumptions(data, styles, ai_paragraphs):
    """Section 13 - Assumptions & Notes"""
    elements = []
    elements.append(Paragraph("14. Assumptions & Notes", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("assumptions", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    assumptions = data.get("assumptions", {})
    rows = [
        ["Electricity Tariff",
         f'Rs. {assumptions.get("electricity_tariff_per_unit", "N/A")}/unit'],
        ["Annual Tariff Escalation",
         f'{assumptions.get("annual_tariff_escalation", 0) * 100:.0f}%'],
        ["System Efficiency (Performance Ratio)",
         f'{assumptions.get("system_efficiency", 0) * 100:.0f}%'],
        ["Panel Degradation / Year",
         f'{assumptions.get("panel_degradation_per_year", 0) * 100:.1f}%'],
        ["Solar Irradiance",
         f'{assumptions.get("average_solar_irradiance_kwh_m2_day", "N/A")} kWh/m2/day'],
        ["Grid Metering", assumptions.get("grid_availability", "N/A")],
        ["Inflation Rate",
         f'{assumptions.get("inflation_rate", 0) * 100:.0f}%'],
    ]
    t = styled_table(["Assumption", "Value"], rows, col_widths=[100*mm, 70*mm])
    elements.append(t)

    elements.append(Spacer(1, 4*mm))
    elements.append(Paragraph(
        "<b>Limitations:</b> Estimates are based on average solar irradiance data "
        "and may not reflect micro-climate variations. Shadow analysis from AR is "
        "approximate. Actual generation depends on panel orientation, weather patterns, "
        "and maintenance.",
        styles["BodyText2"],
    ))
    elements.append(Spacer(1, 4*mm))
    return elements


def build_disclaimer(data, styles, ai_paragraphs):
    """Section 14 - Disclaimer"""
    elements = []
    elements.append(Paragraph("15. Disclaimer", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("disclaimer", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    text = data.get("disclaimer", {}).get("text", "")
    if text:
        elements.append(Paragraph(text, styles["BodyText2"]))
    elements.append(Spacer(1, 6*mm))
    return elements


def build_contact(data, styles, ai_paragraphs):
    """Section 15 - Contact / Next Steps"""
    elements = []
    elements.append(Paragraph("16. Contact & Next Steps", styles["SectionTitle"]))
    elements.append(section_divider())

    ai_text = ai_paragraphs.get("contact", "")
    if ai_text:
        elements.append(Paragraph(ai_text, styles["BodyText2"]))
        elements.append(Spacer(1, 3*mm))

    contact = data.get("contact", {})
    if contact.get("installer_name"):
        rows = [
            ["Installer", contact["installer_name"]],
            ["Phone", contact.get("phone", "N/A")],
            ["Email", contact.get("email", "N/A")],
            ["Website", contact.get("website", "N/A")],
        ]
        t = styled_table(["", ""], rows, col_widths=[50*mm, 120*mm])
        elements.append(t)
        elements.append(Spacer(1, 4*mm))

    steps = contact.get("next_steps", [])
    if steps:
        elements.append(Paragraph("<b>Recommended Next Steps:</b>", styles["BodyText2"]))
        for i, step in enumerate(steps, 1):
            elements.append(Paragraph(
                f'&nbsp;&nbsp;{i}. {step}', styles["BodyText2"],
            ))

    elements.append(Spacer(1, 10*mm))
    # Final thank-you
    elements.append(Paragraph(
        '<para alignment="center"><font size="12" color="#2C3E50">'
        '<b>Thank you for choosing SolarSense AR.</b>'
        '</font></para>',
        styles["BodyText2"],
    ))
    elements.append(Spacer(1, 4*mm))
    elements.append(Paragraph(
        '<para alignment="center"><font size="9" color="#616161">'
        'Save or share this report to take the next step towards clean energy.'
        '</font></para>',
        styles["SmallGrey"],
    ))
    return elements


# ---------------------------------------------------------------------------
# Main generator
# ---------------------------------------------------------------------------
def generate_report(data_path, output_path=None):
    """Load JSON data and produce the PDF report."""

    with open(data_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    base_dir = os.path.dirname(os.path.abspath(data_path))
    output_dir = os.path.join(base_dir, "output")
    os.makedirs(output_dir, exist_ok=True)

    if output_path is None:
        report_id = data.get("report_id", "report")
        output_path = os.path.join(output_dir, f"SolarSense_Report_{report_id}.pdf")

    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        topMargin=18*mm,
        bottomMargin=18*mm,
        leftMargin=15*mm,
        rightMargin=15*mm,
        title="SolarSense AR - Solar Assessment Report",
        author="SolarSense Report Engine",
    )

    styles = build_styles()
    elements = []

    # Generate AI explanatory paragraphs for all sections
    print("Generating AI content for report sections...")
    try:
        ai_paragraphs = generate_all_paragraphs(data, use_cache=True)
        print("AI content ready.\n")
    except Exception as e:
        print(f"Warning: AI content generation failed ({e})")
        print("Generating report without AI paragraphs...\n")
        ai_paragraphs = {}

    # 1. Cover Page (always its own page)
    elements += build_cover_page(data, styles)

    # ------------------------------------------------------------------
    # Layout helpers
    # ------------------------------------------------------------------
    # KeepTogether: prevents a section from being split across pages.
    #   If a section doesn't fit in remaining space, it moves entirely
    #   to the next page.  Reportlab silently degrades for blocks taller
    #   than one full page (lets them split), so this is always safe.
    #
    # CondPageBreak(h): inserts a page break ONLY if less than h of
    #   vertical space remains.  Prevents orphaned titles at the bottom.
    #
    # Strategy per section type:
    #   "small"  — paragraph + table only, fits on one page easily
    #              → wrap entire section in KeepTogether
    #   "large"  — paragraph + table + chart, may exceed one page
    #              → wrap text+table in KeepTogether, chart flows after
    # ------------------------------------------------------------------

    def add_section(section_elements):
        """Small section — keep everything together."""
        elements.append(CondPageBreak(55*mm))
        elements.append(KeepTogether(section_elements))

    def add_section_with_chart(section_elements):
        """Large section — keep text+table together, let chart flow after.
        Split at the last Image element: everything before it is the
        text block, the Image (and any trailing spacer) flows freely.
        """
        # Find the last Image in the list
        split_idx = None
        for i in range(len(section_elements) - 1, -1, -1):
            if isinstance(section_elements[i], Image):
                split_idx = i
                break

        if split_idx is not None:
            text_block = section_elements[:split_idx]
            chart_block = section_elements[split_idx:]
            elements.append(CondPageBreak(55*mm))
            elements.append(KeepTogether(text_block))
            # Chart: only break before it if less than chart height remains
            elements.append(CondPageBreak(80*mm))
            elements.extend(chart_block)
        else:
            # No chart found — treat as small section
            add_section(section_elements)

    # 2. Executive Summary
    add_section(build_executive_summary(data, styles, ai_paragraphs))
    # 3. Rooftop Analysis
    add_section(build_rooftop_analysis(data, styles, ai_paragraphs))
    # 4. System Design
    add_section(build_system_design(data, styles, ai_paragraphs))
    # 5. Energy Estimate (has chart)
    add_section_with_chart(build_energy_estimate(data, styles, output_dir, ai_paragraphs))
    # 6. Cost Breakdown (has chart)
    add_section_with_chart(build_cost_breakdown(data, styles, output_dir, ai_paragraphs))
    # 7. Subsidy Details
    add_section(build_subsidy_details(data, styles, ai_paragraphs))
    # 8. Subsidy Scheme Guide
    add_section(build_subsidy_scheme_guide(data, styles, ai_paragraphs))
    # 9. Savings Analysis
    add_section(build_savings_analysis(data, styles, ai_paragraphs))
    # 10. ROI & Payback (has chart)
    add_section_with_chart(build_roi_analysis(data, styles, output_dir, ai_paragraphs))
    # 11. Provider Comparison (has chart)
    add_section_with_chart(build_provider_comparison(data, styles, output_dir, ai_paragraphs))
    # 12. Environmental Impact
    add_section(build_environmental_impact(data, styles, ai_paragraphs))
    # 13. Visual Output
    add_section(build_visual_output(data, styles, ai_paragraphs))
    # 14. Assumptions & Notes
    add_section(build_assumptions(data, styles, ai_paragraphs))
    # 15. Disclaimer
    add_section(build_disclaimer(data, styles, ai_paragraphs))
    # 16. Contact / Next Steps
    add_section(build_contact(data, styles, ai_paragraphs))

    doc.build(elements, onFirstPage=first_page, onLaterPages=later_pages)
    print(f"Report generated successfully: {output_path}")
    return output_path


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    data_file = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(__file__), "data.json"
    )
    generate_report(data_file)
