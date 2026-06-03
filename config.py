import secrets
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    db_path: str = "platform.db"
    api_key_hash: str = ""
    jwt_secret: str = secrets.token_hex(32)
    jwt_expiry_hours: int = 24

    host: str = "0.0.0.0"
    port: int = 8000

    # MT5 paths (auto-detected or manually configured)
    terminal_path: str = ""
    metaeditor_path: str = ""
    mql5_root: str = ""

    workspace_dir: str = "workspace"
    exports_dir: str = "exports"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
