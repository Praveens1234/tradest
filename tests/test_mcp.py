"""MCP Server smoke tests — import checks and direct tool invocations."""
import pathlib
import asyncio
import pytest


def test_no_duplicate_mcp_run():
    """Regression guard: ensure the duplicate mcp.run() bug is fixed."""
    src = (pathlib.Path(__file__).parent.parent / "mcp_server" / "server.py").read_text()
    count = src.count('mcp.run(transport="stdio")')
    assert count == 1, f"Expected exactly 1 mcp.run call, found {count}"


def test_mcp_server_imports():
    from mcp_server.server import (
        mcp,
        auth_check,
        ea_list,
        ea_create,
        ea_read,
        ea_update,
        ea_delete,
        ea_compile,
        file_tree,
        file_list,
        file_read,
        file_write,
        file_mkdir,
        backtest_run,
        backtest_status,
        backtest_result,
        backtest_cancel,
        backtest_history,
        usage_log,
    )
    assert mcp is not None


@pytest.mark.anyio
async def test_auth_check_invalid_key(monkeypatch):
    import config as cfg
    monkeypatch.setattr(cfg.settings, "api_key_hash", "")
    from mcp_server.server import auth_check
    result = await auth_check("bad-key")
    assert result["valid"] is False


@pytest.mark.anyio
async def test_auth_check_valid_key(monkeypatch):
    import bcrypt
    import config as cfg
    raw = "valid-test-key-abc"
    hashed = bcrypt.hashpw(raw.encode(), bcrypt.gensalt()).decode()
    monkeypatch.setattr(cfg.settings, "api_key_hash", hashed)
    from mcp_server.server import auth_check
    result = await auth_check(raw)
    assert result["valid"] is True


@pytest.mark.anyio
async def test_ea_list_returns_list(workspace):
    from mcp_server.server import ea_list
    result = await ea_list()
    assert isinstance(result, list)


@pytest.mark.anyio
async def test_file_tree_returns_dict(workspace):
    from mcp_server.server import file_tree
    result = await file_tree("")
    assert isinstance(result, dict)
    assert "name" in result
    assert "is_dir" in result


@pytest.mark.anyio
async def test_ea_create_and_read(workspace):
    from mcp_server.server import ea_create, ea_read, ea_delete
    create_result = await ea_create("MCPTestEA", "int x=99;", "mq5")
    assert "id" in create_result
    ea_id = create_result["id"]
    read_result = await ea_read(ea_id)
    assert read_result["content"] == "int x=99;"
    del_result = await ea_delete(ea_id, confirm=True)
    assert del_result["deleted"] is True


@pytest.mark.anyio
async def test_ea_delete_requires_confirm(workspace):
    from mcp_server.server import ea_create, ea_delete
    create_result = await ea_create("ConfirmEA", "x", "mq5")
    ea_id = create_result["id"]
    result = await ea_delete(ea_id, confirm=False)
    assert "error" in result
    # Cleanup
    await ea_delete(ea_id, confirm=True)


@pytest.mark.anyio
async def test_usage_log_returns_list():
    from mcp_server.server import usage_log
    result = await usage_log(limit=10)
    assert isinstance(result, list)


@pytest.mark.anyio
async def test_backtest_history_returns_list():
    from mcp_server.server import backtest_history
    result = await backtest_history(limit=5)
    assert isinstance(result, list)
