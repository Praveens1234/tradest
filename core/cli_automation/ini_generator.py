"""Generate MT5 Strategy Tester INI and .set files."""
import os
import pathlib
import configparser
import tempfile
from dataclasses import dataclass, field


@dataclass
class BacktestParams:
    ea_name: str
    symbol: str = "EURUSD"
    period: str = "H1"
    from_date: str = "2024.01.01"
    to_date: str = "2024.12.31"
    model: int = 1  # 0=Every Tick,1=1Min OHLC,2=Open Prices,3=Math,4=Real Ticks
    deposit: float = 10000.0
    currency: str = "USD"
    leverage: int = 100
    ea_set_params: dict = field(default_factory=dict)
    login: str = ""
    password: str = ""
    server: str = ""
    expert_parameters_path: str = ""


# Map period string to MT5 INI period value
PERIOD_MAP = {
    "M1": 1, "M5": 5, "M15": 15, "M30": 30,
    "H1": 60, "H4": 240, "D1": 1440, "W1": 10080, "MN1": 43200,
}


def generate_ini(params: BacktestParams, run_id: int, exports_dir: str) -> tuple[str, str]:
    """Generate INI and .set files, return (ini_path, set_path)."""
    run_dir = pathlib.Path(exports_dir) / str(run_id)
    run_dir.mkdir(parents=True, exist_ok=True)

    set_path = str(run_dir / "ea_params.set")
    ini_path = str(run_dir / "backtest.ini")

    # Write .set file
    _write_set_file(params.ea_set_params, set_path)

    # Write INI
    period_val = PERIOD_MAP.get(params.period.upper(), 60)
    report_path = str(run_dir / "report")

    lines = [
        "[Tester]",
        f"Expert={params.ea_name}",
        f"ExpertParameters={set_path}",
        f"Symbol={params.symbol}",
        f"Period={period_val}",
        f"Deposit={params.deposit}",
        f"Currency={params.currency}",
        f"Leverage={params.leverage}",
        f"Model={params.model}",
        f"FromDate={params.from_date}",
        f"ToDate={params.to_date}",
        "ForwardMode=0",
        f"Report={report_path}",
        "ReplaceReport=1",
        "ShutdownTerminal=1",
        "Optimization=0",
    ]

    if params.login or params.server:
        lines += [
            "[Common]",
            f"Login={params.login}",
            f"Password={params.password}",
            f"Server={params.server}",
        ]

    ini_content = "\r\n".join(lines) + "\r\n"
    pathlib.Path(ini_path).write_text(ini_content, encoding="utf-8")

    return ini_path, set_path


def _write_set_file(params: dict, path: str) -> None:
    lines = []
    for key, value in params.items():
        lines.append(f"{key}={value}")
    pathlib.Path(path).write_text("\r\n".join(lines), encoding="utf-8")
