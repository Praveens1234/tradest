"""Unit tests for core business logic — no HTTP layer."""
import os
import csv
import pathlib
import tempfile
import pytest


# ─── Compiler log parser ───────────────────────────────────────────────────

def test_parse_log_error():
    from core.compiler import _parse_log
    raw = "C:/mt5/Experts/ea.mq5(15,3) : error : undefined variable 'x'"
    errors, warnings = _parse_log(raw)
    assert len(errors) == 1
    assert errors[0].line == 15
    assert errors[0].col == 3
    assert "undefined variable" in errors[0].message
    assert warnings == []


def test_parse_log_warning():
    from core.compiler import _parse_log
    raw = "C:/mt5/ea.mq5(5,1) : warning : deprecated function"
    errors, warnings = _parse_log(raw)
    assert len(warnings) == 1
    assert errors == []


def test_parse_log_multiple():
    from core.compiler import _parse_log
    raw = (
        "C:/ea.mq5(1,1) : error : error one\n"
        "C:/ea.mq5(2,1) : warning : warn one\n"
        "C:/ea.mq5(3,1) : error : error two\n"
    )
    errors, warnings = _parse_log(raw)
    assert len(errors) == 2
    assert len(warnings) == 1


def test_parse_log_empty():
    from core.compiler import _parse_log
    errors, warnings = _parse_log("")
    assert errors == []
    assert warnings == []


def test_parse_log_information_ignored():
    from core.compiler import _parse_log
    raw = "C:/ea.mq5(1,1) : information : compile started"
    errors, warnings = _parse_log(raw)
    assert errors == []
    assert warnings == []


# ─── INI Generator ─────────────────────────────────────────────────────────

def test_generate_ini_content():
    from core.cli_automation.ini_generator import BacktestParams, generate_ini
    params = BacktestParams(
        ea_name="MyEA",
        symbol="GBPUSD",
        period="D1",
        from_date="2023.01.01",
        to_date="2023.12.31",
        deposit=5000.0,
        leverage=200,
    )
    with tempfile.TemporaryDirectory() as td:
        ini_path, set_path = generate_ini(params, 42, td)
        content = pathlib.Path(ini_path).read_text()
        assert "MyEA" in content
        assert "GBPUSD" in content
        assert "1440" in content  # D1 = 1440
        assert "5000.0" in content
        assert "200" in content
        assert "ForwardMode=0" in content
        assert "ShutdownTerminal=1" in content


def test_generate_ini_set_params():
    from core.cli_automation.ini_generator import BacktestParams, generate_ini
    params = BacktestParams(ea_name="ParamEA", ea_set_params={"LotSize": 0.1, "StopLoss": 50})
    with tempfile.TemporaryDirectory() as td:
        _, set_path = generate_ini(params, 1, td)
        content = pathlib.Path(set_path).read_text()
        assert "LotSize=0.1" in content
        assert "StopLoss=50" in content


def test_period_map():
    from core.cli_automation.ini_generator import PERIOD_MAP
    assert PERIOD_MAP["H1"] == 60
    assert PERIOD_MAP["M1"] == 1
    assert PERIOD_MAP["D1"] == 1440
    assert PERIOD_MAP["W1"] == 10080
    assert PERIOD_MAP["MN1"] == 43200


# ─── Conflict Resolver ─────────────────────────────────────────────────────

def test_check_conflict_no_file():
    from core.file_manager.conflict_resolver import check_conflict
    result = check_conflict("/tmp/definitely_does_not_exist_xyz.mq5")
    assert result is None


def test_check_conflict_existing():
    from core.file_manager.conflict_resolver import check_conflict
    with tempfile.NamedTemporaryFile(suffix=".mq5", delete=False) as f:
        f.write(b"test")
        tmp = f.name
    try:
        result = check_conflict(tmp)
        assert result is not None
        assert result.conflict is True
        assert result.size_bytes == 4
        assert result.suggested_name.endswith(".mq5")
        assert "_1" in result.suggested_name
    finally:
        os.unlink(tmp)


def test_suggested_name_increments():
    from core.file_manager.conflict_resolver import check_conflict
    with tempfile.TemporaryDirectory() as td:
        p = pathlib.Path(td) / "ea.mq5"
        p.write_text("original")
        p1 = pathlib.Path(td) / "ea_1.mq5"
        p1.write_text("copy1")
        result = check_conflict(str(p))
        assert result.suggested_name == "ea_2.mq5"


# ─── Path Traversal Guard ───────────────────────────────────────────────────

def test_safe_resolve_valid():
    from core.file_manager.fs_navigator import _safe_resolve
    with tempfile.TemporaryDirectory() as td:
        result = _safe_resolve("subdir/file.mq5", td)
        assert str(result).startswith(td)


def test_safe_resolve_traversal():
    from core.file_manager.fs_navigator import _safe_resolve
    with tempfile.TemporaryDirectory() as td:
        with pytest.raises(ValueError, match="traversal"):
            _safe_resolve("../../etc/passwd", td)


def test_safe_resolve_absolute_outside():
    from core.file_manager.fs_navigator import _safe_resolve
    with tempfile.TemporaryDirectory() as td:
        with pytest.raises(ValueError):
            _safe_resolve("/etc/passwd", td)


# ─── CSV Ledger Exporter ───────────────────────────────────────────────────

def test_export_csv():
    from core.ledger_exporter import export_csv
    trades = [
        {"ticket": 1, "profit": 10.5, "symbol": "EURUSD"},
        {"ticket": 2, "profit": -5.0, "symbol": "GBPUSD"},
    ]
    with tempfile.TemporaryDirectory() as td:
        path = export_csv(trades, 99, td)
        assert path.endswith("ledger.csv")
        with open(path) as f:
            reader = csv.DictReader(f)
            rows = list(reader)
        assert len(rows) == 2
        assert rows[0]["ticket"] == "1"
        assert rows[1]["symbol"] == "GBPUSD"


def test_export_csv_empty():
    from core.ledger_exporter import export_csv
    with tempfile.TemporaryDirectory() as td:
        path = export_csv([], 99, td)
        assert path == ""


# ─── Zip Exporter ──────────────────────────────────────────────────────────

def test_zip_with_zipfile_folder():
    from core.file_manager.zip_exporter import _zip_with_zipfile
    import zipfile as zf_mod
    with tempfile.TemporaryDirectory() as td:
        p = pathlib.Path(td)
        (p / "file1.mq5").write_text("hello")
        (p / "file2.mq5").write_text("world")
        data = _zip_with_zipfile(p)
        assert len(data) > 0
        with zf_mod.ZipFile(__import__("io").BytesIO(data)) as z:
            names = z.namelist()
        assert any("file1.mq5" in n for n in names)
        assert any("file2.mq5" in n for n in names)


def test_zip_with_zipfile_single_file():
    from core.file_manager.zip_exporter import _zip_with_zipfile
    import zipfile as zf_mod
    with tempfile.TemporaryDirectory() as td:
        p = pathlib.Path(td) / "single.mq5"
        p.write_text("content")
        data = _zip_with_zipfile(p)
        with zf_mod.ZipFile(__import__("io").BytesIO(data)) as z:
            assert "single.mq5" in z.namelist()


# ─── Result Parser ─────────────────────────────────────────────────────────

def test_normalize_key():
    from core.cli_automation.result_parser import _normalize_key
    assert _normalize_key("Net Profit") == "net_profit"
    assert _normalize_key("Total Trades!") == "total_trades"   # trailing ! → _ → stripped
    assert _normalize_key("  Profit Factor  ") == "profit_factor"


def test_try_float_number():
    from core.cli_automation.result_parser import _try_float
    assert _try_float("1,234.56") == 1234.56
    assert _try_float("50%") == 50.0
    assert _try_float("-10.5") == -10.5


def test_try_float_string():
    from core.cli_automation.result_parser import _try_float
    assert _try_float("EURUSD") == "EURUSD"
    assert _try_float("") == ""


def test_parse_html_report_fallback():
    from core.cli_automation.result_parser import parse_html_report
    with tempfile.NamedTemporaryFile(suffix=".html", delete=False, mode="w", encoding="utf-8") as f:
        f.write("<html><body><table><tr><th>Net Profit</th><th>100</th></tr></table></body></html>")
        tmp = f.name
    try:
        result = parse_html_report(tmp)
        assert "metrics" in result
        assert "trades" in result
    finally:
        os.unlink(tmp)


# ─── Report Exporter ───────────────────────────────────────────────────────

@pytest.mark.anyio
async def test_capture_reports_copies_files():
    from core.report_exporter import capture_reports
    with tempfile.TemporaryDirectory() as td:
        html_src = pathlib.Path(td) / "report.html"
        xml_src = pathlib.Path(td) / "report.xml"
        html_src.write_text("<html/>")
        xml_src.write_text("<xml/>")
        result = await capture_reports(1, str(html_src), str(xml_src), td)
        assert "html" in result
        assert "xml" in result
        assert pathlib.Path(result["html"]).exists()
        assert pathlib.Path(result["xml"]).exists()
