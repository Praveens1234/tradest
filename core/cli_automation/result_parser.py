"""Parse MT5 HTML and XML backtest reports into metrics + trades."""
import re
import csv
import pathlib
import logging
from xml.etree import ElementTree as ET
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)


def parse_html_report(html_path: str) -> dict:
    """Parse MT5 HTML report. Returns {metrics: dict, trades: list[dict]}."""
    try:
        content = pathlib.Path(html_path).read_text(encoding="utf-16-le", errors="replace")
    except UnicodeDecodeError:
        content = pathlib.Path(html_path).read_text(encoding="utf-8", errors="replace")

    soup = BeautifulSoup(content, "lxml")
    metrics = _extract_metrics(soup)
    trades = _extract_trades(soup)
    return {"metrics": metrics, "trades": trades}


def parse_xml_report(xml_path: str) -> dict:
    """Parse MT5 Open XML (Excel 2007) report."""
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
    except ET.ParseError as exc:
        logger.error("XML parse error: %s", exc)
        return {"metrics": {}, "trades": []}

    # MT5 XML has two sheets: Summary and Trades
    ns = {"ss": "urn:schemas-microsoft-com:office:spreadsheet"}
    metrics: dict = {}
    trades: list[dict] = []

    worksheets = root.findall(".//ss:Worksheet", ns)
    for ws in worksheets:
        name_attr = ws.get("{urn:schemas-microsoft-com:office:spreadsheet}Name", "")
        rows = ws.findall(".//ss:Row", ns)
        if "summary" in name_attr.lower() or len(worksheets) == 1:
            for row in rows:
                cells = row.findall("ss:Cell/ss:Data", ns)
                if len(cells) >= 2:
                    key = (cells[0].text or "").strip()
                    val = (cells[1].text or "").strip()
                    if key:
                        metrics[_normalize_key(key)] = _try_float(val)
        elif "trade" in name_attr.lower() or "deal" in name_attr.lower():
            headers: list[str] = []
            for i, row in enumerate(rows):
                cells = [c.text or "" for c in row.findall("ss:Cell/ss:Data", ns)]
                if i == 0:
                    headers = [_normalize_key(c) for c in cells]
                else:
                    if len(cells) == len(headers):
                        trades.append({h: _try_float(v) for h, v in zip(headers, cells)})

    return {"metrics": metrics, "trades": trades}


def _extract_metrics(soup: BeautifulSoup) -> dict:
    metrics: dict = {}
    tables = soup.find_all("table")
    for table in tables:
        rows = table.find_all("tr")
        for row in rows:
            cells = row.find_all(["td", "th"])
            if len(cells) >= 2:
                key = cells[0].get_text(strip=True)
                val = cells[1].get_text(strip=True)
                if key and len(key) < 80:
                    metrics[_normalize_key(key)] = _try_float(val)
    return metrics


def _extract_trades(soup: BeautifulSoup) -> list[dict]:
    trades: list[dict] = []
    tables = soup.find_all("table")
    for table in tables:
        rows = table.find_all("tr")
        if len(rows) < 3:
            continue
        headers = [th.get_text(strip=True) for th in rows[0].find_all(["th", "td"])]
        if not any(h.lower() in ("deal", "order", "ticket", "profit") for h in headers):
            continue
        for row in rows[1:]:
            cells = [td.get_text(strip=True) for td in row.find_all(["td", "th"])]
            if len(cells) == len(headers):
                trades.append({_normalize_key(h): _try_float(v) for h, v in zip(headers, cells)})
    return trades


def _normalize_key(key: str) -> str:
    return re.sub(r"[^a-z0-9_]", "_", key.lower().strip()).strip("_")


def _try_float(val: str):
    try:
        return float(val.replace(",", "").replace(" ", "").replace("%", ""))
    except (ValueError, AttributeError):
        return val
