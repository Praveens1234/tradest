from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import DeclarativeBase, relationship


class Base(DeclarativeBase):
    pass


class EAFile(Base):
    __tablename__ = "ea_files"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    path = Column(String(1024), nullable=False, unique=True)
    type = Column(String(10), nullable=False, default="mq5")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    compile_logs = relationship("CompileLog", back_populates="ea", cascade="all, delete-orphan")
    backtest_runs = relationship("BacktestRun", back_populates="ea", cascade="all, delete-orphan")


class CompileLog(Base):
    __tablename__ = "compile_logs"

    id = Column(Integer, primary_key=True, index=True)
    ea_id = Column(Integer, ForeignKey("ea_files.id"), nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)
    status = Column(String(20), nullable=False)  # success, warning, error
    errors_json = Column(Text, default="[]")
    warnings_json = Column(Text, default="[]")
    raw_log = Column(Text, default="")

    ea = relationship("EAFile", back_populates="compile_logs")


class BacktestRun(Base):
    __tablename__ = "backtest_runs"

    id = Column(Integer, primary_key=True, index=True)
    ea_id = Column(Integer, ForeignKey("ea_files.id"), nullable=True)
    parameters_json = Column(Text, default="{}")
    test_type = Column(String(50), default="backtest")
    status = Column(String(20), default="pending")  # pending, running, done, failed, cancelled
    pid = Column(Integer, nullable=True)
    started_at = Column(DateTime, nullable=True)
    finished_at = Column(DateTime, nullable=True)

    ea = relationship("EAFile", back_populates="backtest_runs")
    result = relationship("BacktestResult", back_populates="run", uselist=False, cascade="all, delete-orphan")


class BacktestResult(Base):
    __tablename__ = "backtest_results"

    id = Column(Integer, primary_key=True, index=True)
    run_id = Column(Integer, ForeignKey("backtest_runs.id"), nullable=False, unique=True)
    metrics_json = Column(Text, default="{}")
    trades_json = Column(Text, default="[]")
    html_path = Column(String(1024), nullable=True)
    xml_path = Column(String(1024), nullable=True)
    csv_path = Column(String(1024), nullable=True)

    run = relationship("BacktestRun", back_populates="result")


class UsageEvent(Base):
    __tablename__ = "usage_events"

    id = Column(Integer, primary_key=True, index=True)
    interface = Column(String(20), nullable=False)  # API, MCP, WebUI, Flutter
    action = Column(String(100), nullable=False)
    ea_id = Column(Integer, nullable=True)
    run_id = Column(Integer, nullable=True)
    duration_ms = Column(Integer, nullable=True)
    status = Column(String(20), default="ok")
    error_msg = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)


class PlatformLog(Base):
    __tablename__ = "platform_logs"

    id = Column(Integer, primary_key=True, index=True)
    level = Column(String(10), nullable=False)       # DEBUG INFO WARNING ERROR CRITICAL
    logger_name = Column(String(100), nullable=False)
    message = Column(Text, nullable=False)
    context_json = Column(Text, default="{}")
    timestamp = Column(DateTime, default=datetime.utcnow)
