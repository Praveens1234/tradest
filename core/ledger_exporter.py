"""Export backtest trades list to CSV ledger."""
import csv
import pathlib
import logging

logger = logging.getLogger(__name__)


def export_csv(trades: list[dict], run_id: int, exports_dir: str) -> str:
    """Write trades to exports/<run_id>/ledger.csv and return path."""
    if not trades:
        return ""

    run_dir = pathlib.Path(exports_dir) / str(run_id)
    run_dir.mkdir(parents=True, exist_ok=True)
    csv_path = run_dir / "ledger.csv"

    fieldnames = list(trades[0].keys()) if trades else []
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(trades)

    logger.info("Ledger exported: %s (%d trades)", csv_path, len(trades))
    return str(csv_path)
