"""
SolarSense AR - AI Content Generator
Generates human-sounding explanatory paragraphs for each report section
using OpenAI API. Each section gets a tailored system prompt and receives
the actual user data so the text references real numbers.
"""

import json
import os
import hashlib
import tempfile

from openai import OpenAI
from dotenv import load_dotenv

# Load .env file from the project directory
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
MODEL = "gpt-4o-mini"  # cost-effective, fast, good quality

_BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Deployment bundles on Vercel etc. are read-only; fall back to the system
# temp dir so the cache writes don't blow up the whole AI step.
if os.environ.get("VERCEL") or not os.access(_BASE_DIR, os.W_OK):
    CACHE_DIR = os.path.join(tempfile.gettempdir(), "solarsense_ai_cache")
else:
    CACHE_DIR = os.path.join(_BASE_DIR, "output", ".ai_cache")


def _get_client():
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError(
            "OPENAI_API_KEY environment variable is not set. "
            "Set it before running: export OPENAI_API_KEY='sk-...'"
        )
    return OpenAI(api_key=api_key)


# ---------------------------------------------------------------------------
# Cache helpers — avoid repeated API calls during development
# ---------------------------------------------------------------------------
def _cache_key(section_name, user_prompt):
    raw = f"{section_name}::{user_prompt}"
    return hashlib.md5(raw.encode()).hexdigest()


def _read_cache(section_name, user_prompt):
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, _cache_key(section_name, user_prompt) + ".txt")
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    return None


def _write_cache(section_name, user_prompt, content):
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, _cache_key(section_name, user_prompt) + ".txt")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


# ---------------------------------------------------------------------------
# Core API call
# ---------------------------------------------------------------------------
def _call_openai(system_prompt, user_prompt, section_name, use_cache=True):
    """Call OpenAI with caching support."""
    if use_cache:
        cached = _read_cache(section_name, user_prompt)
        if cached:
            return cached

    client = _get_client()
    response = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.7,
        max_tokens=500,
    )
    content = response.choices[0].message.content.strip()

    if use_cache:
        _write_cache(section_name, user_prompt, content)

    return content


# ---------------------------------------------------------------------------
# Section-specific system prompts
# ---------------------------------------------------------------------------

SYSTEM_PROMPTS = {

    "executive_summary": (
        "You are a senior solar energy consultant writing a professional solar "
        "assessment report for a homeowner in India. Write a detailed executive summary "
        "paragraph (7-8 sentences) that explains what the report covers, highlights "
        "the recommended system size and why it fits the property, the total and net "
        "cost after subsidy, the payback period, lifetime savings over 25 years, and "
        "the environmental benefit. Conclude by giving the homeowner confidence that "
        "solar is a sound financial and environmental decision for their specific "
        "property and location. Use the actual numbers provided throughout. Keep the "
        "tone professional and informative — like a detailed consultant brief, not a "
        "sales pitch. Do NOT use bullet points. Do NOT use markdown. Plain text only."
    ),

    "rooftop_analysis": (
        "You are a solar rooftop engineer writing a detailed explanation paragraph for "
        "a solar assessment report. The homeowner's rooftop has been scanned using "
        "Augmented Reality technology on a smartphone. Write 6-7 sentences explaining "
        "how the AR scan works to measure the rooftop, how the total area was captured, "
        "what specific obstacles were identified and how much area they consume, how the "
        "usable area was determined after excluding obstacles and shadow zones, how many "
        "panels can be accommodated in the usable space, and what the proposed panel "
        "layout looks like. Reference the actual area numbers and panel count. Keep it "
        "clear for a non-technical reader but thorough. Do NOT use bullet points or "
        "markdown. Write plain text only."
    ),

    "system_design": (
        "You are a solar system designer writing a detailed paragraph for a homeowner's "
        "solar report. Write 6-7 sentences explaining the recommended system "
        "configuration: the specific panel model, wattage, and type being used, how "
        "many panels make up the system and why this count was chosen based on rooftop "
        "area and the homeowner's electricity consumption, what system size in kW this "
        "results in, the role of the inverter and why the selected brand and capacity "
        "are appropriate, expected system efficiency, annual degradation rate, and "
        "expected lifetime. Make technical details accessible to someone with no solar "
        "knowledge while still being thorough. Reference the actual specs. Do NOT use "
        "bullet points or markdown. Write plain text only."
    ),

    "energy_estimate": (
        "You are a solar energy analyst writing a detailed paragraph for a homeowner's "
        "report. Write 6-7 sentences explaining what the energy generation estimates "
        "mean in practical terms: how much electricity the system will produce on an "
        "average month and over a full year, how this compares to the homeowner's current "
        "monthly consumption, whether the system can cover their entire electricity needs "
        "or a significant portion, how solar generation varies across seasons (summer "
        "peaks vs monsoon dips), what performance ratio means and how average sun hours "
        "in their city affect output, and what net metering means for any surplus units "
        "generated. Use the actual numbers. Keep it relatable. Do NOT use bullet points "
        "or markdown. Write plain text only."
    ),

    "cost_breakdown": (
        "You are a solar finance advisor writing a detailed cost explanation paragraph "
        "for a homeowner's report. Write 6-7 sentences breaking down where their money "
        "goes: the cost of solar panels (the largest component), the inverter and why it "
        "is essential, the mounting structure that secures panels to the roof, wiring and "
        "electrical accessories, installation labour, and net metering charges for grid "
        "connection. Explain what the price-per-watt metric means and how the total cost "
        "compares to market rates in their region. Reassure them that the pricing is "
        "transparent and competitive. Reference the actual cost numbers for each "
        "component. Do NOT use bullet points or markdown. Write plain text only."
    ),

    "subsidy_details": (
        "You are a government solar subsidy expert writing a detailed paragraph for a "
        "homeowner's solar report. Write 7-8 sentences explaining the PM Surya Ghar "
        "Muft Bijli Yojana scheme: what the scheme is and its objective of promoting "
        "rooftop solar across Indian households, who qualifies for the subsidy, how the "
        "subsidy amount is calculated based on system size (the slab-based structure for "
        "different kW ranges), the specific subsidy amount this homeowner is eligible for "
        "and what percentage of the total cost it covers, how the net payable amount was "
        "derived, what steps the homeowner needs to take to apply for and claim the "
        "subsidy through the national portal, and the expected timeline for disbursement. "
        "Reference the actual subsidy amount and final cost. Plain text only, no bullet "
        "points or markdown."
    ),

    "subsidy_scheme_guide": (
        "You are a government policy expert writing a detailed introductory paragraph "
        "for the PM Surya Ghar Muft Bijli Yojana complete guide section. Write 7-8 "
        "sentences providing an overview of India's flagship rooftop solar subsidy scheme: "
        "when it was launched and its goal of installing rooftop solar on one crore "
        "households, the slab-based subsidy structure (up to Rs 30,000/kW for first 2 kW, "
        "Rs 18,000/kW for 2-3 kW, with a cap of Rs 78,000 for systems above 3 kW), who is "
        "eligible including the requirement for grid-connected residential consumers, the "
        "13-step application process from registration to subsidy disbursement, how state "
        "subsidies from states like Gujarat, Maharashtra, and Tamil Nadu can stack on top, "
        "and the financing options available through banks like SBI and PNB. Emphasize that "
        "the scheme makes solar accessible and affordable for every Indian household. "
        "Reference actual subsidy amounts. Plain text only, no bullet points or markdown."
    ),

    "savings_analysis": (
        "You are a personal finance advisor writing a detailed savings explanation for a "
        "homeowner considering solar. Write 6-7 sentences explaining what their monthly, "
        "annual, and 25-year savings mean in real terms: how much they currently spend on "
        "electricity and how much of that solar will offset each month, what the annual "
        "savings amount to and how it could be redirected to other household needs or "
        "investments, how savings compound over the 25-year system lifetime into a "
        "substantial sum, why electricity tariffs in India have historically risen by "
        "3-5% annually and how this makes solar savings increasingly valuable over time, "
        "and how net metering allows them to earn credits for surplus power exported to "
        "the grid. Use their actual savings numbers. Plain text only, no bullet points "
        "or markdown."
    ),

    "roi_analysis": (
        "You are an investment analyst writing a detailed ROI explanation for a "
        "homeowner's solar report. Write 7-8 sentences explaining what the payback "
        "period means — the number of years before their cumulative savings exceed "
        "their net investment, what happens financially after the break-even year when "
        "the system essentially generates free electricity, what the ROI percentage "
        "represents over 25 years and how it compares to traditional Indian investment "
        "options like fixed deposits (6-7%), PPF (7%), or equity mutual funds (12-15%), "
        "how the cumulative cash flow chart should be read (negative years represent "
        "investment recovery, positive years represent pure profit), and why solar is "
        "considered a low-risk, inflation-hedged investment since it protects against "
        "rising electricity costs. Use the actual numbers. Plain text only, no bullet "
        "points or markdown."
    ),

    "provider_comparison": (
        "You are a solar marketplace analyst writing a detailed provider comparison "
        "paragraph for a homeowner's report. The comparison includes 7 major Indian solar "
        "providers: Tata Power Solar, Adani Solar, Waaree Energies, Vikram Solar, Luminous "
        "Solar, Havells Solar, and Loom Solar. Write 6-7 sentences explaining: which "
        "provider is currently selected and why they are a strong choice, how these real "
        "Indian providers compare across price per watt range, panel efficiency, warranty "
        "duration, and ALMM certification status, what trade-offs exist between premium "
        "brands like Tata Power Solar and more affordable options like Loom Solar, why "
        "factors like ALMM listing (required for subsidy eligibility), after-sales service "
        "network, and local installation quality matter as much as upfront price, and what "
        "the homeowner should verify before making a final decision. Reference actual "
        "provider names, ratings, and efficiency numbers from the comparison data. Plain "
        "text only, no bullet points or markdown."
    ),

    "environmental_impact": (
        "You are an environmental scientist writing a detailed paragraph for a "
        "homeowner's solar report. Write 6-7 sentences explaining the environmental "
        "impact of their solar installation: the annual CO2 reduction in tons and what "
        "that means in relatable terms, the equivalent number of trees that would need "
        "to be planted to achieve the same carbon offset, the cumulative lifetime CO2 "
        "savings over 25 years, how this contributes to India's nationally determined "
        "contributions under the Paris Agreement and the country's target of 500 GW "
        "renewable energy by 2030, and how each rooftop installation helps reduce "
        "dependence on coal-fired power plants. Make the homeowner feel proud of their "
        "contribution to a cleaner environment. Use actual numbers. Plain text only, "
        "no bullet points or markdown."
    ),

    "visual_output": (
        "You are a solar AR technology specialist writing a detailed paragraph "
        "explaining the visual outputs in the report. Write 5-6 sentences describing "
        "how the AR rooftop scan uses the smartphone camera and sensors to capture real "
        "rooftop dimensions, identify obstacles like water tanks and staircase structures, "
        "and map shadow zones, how the panel placement visualization generates a "
        "realistic layout showing exactly where each panel will be positioned on the "
        "roof with proper spacing and orientation, why this AR-based approach gives far "
        "more accurate results than manual estimation, and how the homeowner can use "
        "these visuals to discuss the installation plan with family or the installer. "
        "Plain text only, no bullet points or markdown."
    ),

    "assumptions": (
        "You are a solar engineer writing a detailed transparency note for a homeowner's "
        "report. Write 6-7 sentences explaining that all calculations in this report are "
        "based on standard industry assumptions: the electricity tariff rate used and "
        "the assumed annual escalation, the solar irradiance data specific to their city "
        "and what it represents, the panel degradation rate that accounts for gradual "
        "efficiency loss over decades, the system performance ratio that factors in "
        "real-world losses from heat, dust, and wiring, and the inflation rate used for "
        "long-term financial projections. Emphasize that these assumptions are "
        "conservative and based on industry standards, so actual results are likely to "
        "meet or exceed these estimates. This builds trust and sets realistic "
        "expectations. Plain text only, no bullet points or markdown."
    ),

    "disclaimer": (
        "You are a compliance writer adding context before the legal disclaimer in a "
        "solar assessment report. Write 4-5 sentences that set expectations clearly: "
        "actual performance depends on real-world conditions including local weather "
        "patterns, panel maintenance, shading changes over time, and grid availability, "
        "why a professional on-site survey is the recommended next step to validate "
        "the AR-based estimates, how local DISCOM policies on net metering may affect "
        "savings projections, and that this report provides a strong, data-backed "
        "starting point for informed decision-making. Keep it honest and professional "
        "but not discouraging. Plain text only, no bullet points or markdown."
    ),

    "contact": (
        "You are a helpful solar advisor writing a closing paragraph that motivates "
        "the homeowner to take the next step. Write 6-7 sentences encouraging them to: "
        "reach out to the listed installer to schedule a free on-site survey for precise "
        "measurements, begin the subsidy application process on the national portal while "
        "the scheme is active, contact their local DISCOM for net metering approval which "
        "is required before installation, share this report with family members to discuss "
        "the investment together, and understand that the best time to go solar is now "
        "given rising electricity tariffs and available government incentives. End with a "
        "confident, warm note about how solar is one of the smartest long-term investments "
        "for an Indian household. Plain text only, no bullet points or markdown."
    ),
}


# ---------------------------------------------------------------------------
# User prompt builders — extract relevant data for each section
# ---------------------------------------------------------------------------

def _build_user_prompt(section_name, data):
    """Build a user prompt with actual data for the given section."""
    user = data["user"]
    inp = data["input_data"]
    se = data["solar_estimation"]
    eo = data["energy_output"]
    fin = data["financial_analysis"]
    sav = data["savings"]
    roi = data["roi_analysis"]
    env = data["environmental_impact"]
    assumptions = data.get("assumptions", {})

    prompts = {
        "executive_summary": (
            f"User: {user['name']}, Location: {user['location']['city']}, "
            f"{user['location']['state']}. "
            f"System size: {se['system_size_kw']} kW, "
            f"Total cost: Rs. {fin['cost']['total_installation_cost']:,}, "
            f"Subsidy: Rs. {fin['subsidy']['subsidy_amount']:,}, "
            f"Net cost: Rs. {fin['net_cost']:,}, "
            f"Payback: {roi['payback_period_years']} years, "
            f"25-year savings: Rs. {sav['lifetime_savings_25yr']:,}, "
            f"ROI: {roi['roi_percentage']}%. "
            f"Monthly bill currently: Rs. {inp['monthly_bill']:,}."
        ),

        "rooftop_analysis": (
            f"Total rooftop area: {inp['rooftop']['total_area_sqm']} sq.m, "
            f"Usable area: {inp['rooftop']['usable_area_sqm']} sq.m, "
            f"Obstacle area: {inp['rooftop']['obstacles_area_sqm']} sq.m, "
            f"Obstacles: {inp['rooftop'].get('obstacle_details', 'N/A')}, "
            f"Panels that fit: {se['panel']['number_of_panels']} "
            f"({se['panel']['area_per_panel_sqm']} sq.m each), "
            f"Layout: {se.get('layout_description', 'N/A')}."
        ),

        "system_design": (
            f"System: {se['system_size_kw']} kW, "
            f"Panels: {se['panel']['number_of_panels']} x {se['panel']['watt_per_panel']}W "
            f"{se['panel'].get('panel_model', '')}, type: {se['panel'].get('panel_type', '')}, "
            f"Inverter: {se.get('inverter', {}).get('brand', 'N/A')} "
            f"{se.get('inverter', {}).get('capacity_kw', '')} kW "
            f"({se.get('inverter', {}).get('type', '')}), "
            f"Efficiency: {se['efficiency']*100:.0f}%, "
            f"Lifetime: {se.get('system_lifetime_years', 25)} years, "
            f"Monthly consumption: {inp['monthly_units']} units, "
            f"Usable area: {inp['rooftop']['usable_area_sqm']} sq.m."
        ),

        "energy_estimate": (
            f"Monthly generation: {eo['monthly_units_generated']} kWh, "
            f"Annual generation: {eo['annual_units_generated']} kWh, "
            f"Performance ratio: {eo['performance_ratio']*100:.0f}%, "
            f"Sun hours/day: {eo.get('average_sun_hours_per_day', 'N/A')}, "
            f"User's current consumption: {inp['monthly_units']} units/month, "
            f"Location: {user['location']['city']}."
        ),

        "cost_breakdown": (
            f"Price per watt: Rs. {fin['cost']['price_per_watt']}, "
            f"Total cost: Rs. {fin['cost']['total_installation_cost']:,}. "
            f"Breakdown: {json.dumps(fin['cost'].get('component_breakdown', {}))}, "
            f"Provider: {inp['provider_selected']}, City: {user['location']['city']}."
        ),

        "subsidy_details": (
            f"Scheme: {fin['subsidy']['scheme']}, "
            f"Eligible: {'Yes' if fin['subsidy']['eligible'] else 'No'}, "
            f"Subsidy amount: Rs. {fin['subsidy']['subsidy_amount']:,}, "
            f"Calculation: {fin['subsidy'].get('subsidy_detail', 'N/A')}, "
            f"Subsidy %: {fin['subsidy'].get('subsidy_percentage', 'N/A')}%, "
            f"Total cost: Rs. {fin['cost']['total_installation_cost']:,}, "
            f"Net cost after subsidy: Rs. {fin['net_cost']:,}, "
            f"System size: {se['system_size_kw']} kW."
        ),

        "subsidy_scheme_guide": (
            f"System size: {se['system_size_kw']} kW, "
            f"Total cost: Rs. {fin['cost']['total_installation_cost']:,}, "
            f"Subsidy amount: Rs. {fin['subsidy']['subsidy_amount']:,}, "
            f"Net cost: Rs. {fin['net_cost']:,}, "
            f"Location: {user['location']['city']}, {user['location']['state']}. "
            f"Subsidy scheme: {fin['subsidy']['scheme']}. "
            f"The guide covers subsidy slabs, eligibility, required documents, "
            f"13-step application process, state subsidies, and bank financing options."
        ),

        "savings_analysis": (
            f"Monthly savings: Rs. {sav['monthly_savings']:,}, "
            f"Annual savings: Rs. {sav['annual_savings']:,}, "
            f"25-year savings: Rs. {sav['lifetime_savings_25yr']:,}, "
            f"Current monthly bill: Rs. {inp['monthly_bill']:,}, "
            f"Tariff escalation: {assumptions.get('annual_tariff_escalation', 0)*100:.0f}%/yr."
        ),

        "roi_analysis": (
            f"Payback period: {roi['payback_period_years']} years, "
            f"ROI: {roi['roi_percentage']}%, "
            f"Break-even year: {roi['breakeven_year']}, "
            f"Net investment: Rs. {fin['net_cost']:,}, "
            f"Annual savings: Rs. {sav['annual_savings']:,}, "
            f"25-year savings: Rs. {sav['lifetime_savings_25yr']:,}."
        ),

        "provider_comparison": (
            f"Selected: {inp['provider_selected']}. "
            f"Providers: {json.dumps(data['provider_comparison'])}."
        ),

        "environmental_impact": (
            f"CO2 saved/year: {env['co2_savings_per_year_tons']} tons, "
            f"25-year CO2: {env.get('co2_savings_lifetime_tons', 'N/A')} tons, "
            f"Trees equivalent: {env['trees_equivalent']}, "
            f"System size: {se['system_size_kw']} kW, "
            f"Location: {user['location']['city']}, {user['location']['state']}."
        ),

        "visual_output": (
            f"The rooftop was scanned using AR technology on the user's smartphone. "
            f"Rooftop area: {inp['rooftop']['total_area_sqm']} sq.m, "
            f"Panels placed: {se['panel']['number_of_panels']}, "
            f"Layout: {se.get('layout_description', 'N/A')}."
        ),

        "assumptions": (
            f"Tariff: Rs. {assumptions.get('electricity_tariff_per_unit', 'N/A')}/unit, "
            f"Escalation: {assumptions.get('annual_tariff_escalation', 0)*100:.0f}%/yr, "
            f"Efficiency: {assumptions.get('system_efficiency', 0)*100:.0f}%, "
            f"Degradation: {assumptions.get('panel_degradation_per_year', 0)*100:.1f}%/yr, "
            f"Irradiance: {assumptions.get('average_solar_irradiance_kwh_m2_day', 'N/A')} "
            f"kWh/m2/day, Grid: {assumptions.get('grid_availability', 'N/A')}, "
            f"City: {user['location']['city']}."
        ),

        "disclaimer": (
            f"System: {se['system_size_kw']} kW at {user['location']['city']}, "
            f"estimated via AR scan and standard irradiance data."
        ),

        "contact": (
            f"Installer: {data.get('contact', {}).get('installer_name', 'N/A')}, "
            f"Subsidy scheme: {fin['subsidy']['scheme']}, "
            f"Net cost: Rs. {fin['net_cost']:,}, "
            f"Payback: {roi['payback_period_years']} years, "
            f"25-year savings: Rs. {sav['lifetime_savings_25yr']:,}."
        ),
    }

    return prompts.get(section_name, "Generate a brief explanatory paragraph.")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def generate_section_paragraph(section_name, data, use_cache=True):
    """
    Generate an AI-written explanatory paragraph for a report section.

    Args:
        section_name: One of the keys in SYSTEM_PROMPTS
        data: The full report data dict (from data.json)
        use_cache: If True, cache responses to avoid repeated API calls

    Returns:
        str: The generated paragraph text
    """
    system_prompt = SYSTEM_PROMPTS.get(section_name)
    if not system_prompt:
        return ""

    user_prompt = _build_user_prompt(section_name, data)
    return _call_openai(system_prompt, user_prompt, section_name, use_cache)


def generate_all_paragraphs(data, use_cache=True):
    """
    Generate paragraphs for all sections at once.

    Returns:
        dict: {section_name: paragraph_text}
    """
    paragraphs = {}
    for section_name in SYSTEM_PROMPTS:
        print(f"  Generating AI content: {section_name}...")
        paragraphs[section_name] = generate_section_paragraph(
            section_name, data, use_cache
        )
    return paragraphs
