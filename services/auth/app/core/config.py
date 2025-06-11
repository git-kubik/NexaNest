import secrets
from pathlib import Path
from typing import Any, List, Optional, Union

from pydantic import AnyHttpUrl, PostgresDsn, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def read_secret_file(file_path: Optional[str]) -> Optional[str]:
    """Read secret from Docker secrets file if it exists."""
    if not file_path:
        return None
    
    try:
        secret_path = Path(file_path)
        if secret_path.exists():
            return secret_path.read_text().strip()
    except Exception:
        pass
    return None


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
    )

    # Project info
    PROJECT_NAME: str = "NexaNest Auth Service"
    VERSION: str = "0.1.0"
    DEBUG: bool = False
    API_V1_STR: str = "/api/v1"

    # Security - Docker secrets support
    SECRET_KEY: str = secrets.token_urlsafe(32)
    SECRET_KEY_FILE: Optional[str] = None
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    ALGORITHM: str = "HS256"
    BCRYPT_ROUNDS: int = 12
    
    def get_secret_key(self) -> str:
        """Get secret key from file or environment variable."""
        secret_from_file = read_secret_file(self.SECRET_KEY_FILE)
        return secret_from_file or self.SECRET_KEY
    
    # CORS
    BACKEND_CORS_ORIGINS: List[AnyHttpUrl] = []

    @field_validator("BACKEND_CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> Union[List[str], str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)

    # Database - Docker secrets support
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_USER: str = "nexanest"
    POSTGRES_PASSWORD: str = "nexanest_dev_password"
    POSTGRES_PASSWORD_FILE: Optional[str] = None
    POSTGRES_DB: str = "auth"
    DATABASE_URL: Optional[PostgresDsn] = None
    
    def get_postgres_password(self) -> str:
        """Get PostgreSQL password from file or environment variable."""
        password_from_file = read_secret_file(self.POSTGRES_PASSWORD_FILE)
        return password_from_file or self.POSTGRES_PASSWORD

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def assemble_db_connection(cls, v: Optional[str], info) -> Any:
        if isinstance(v, str):
            return v
        values = info.data
        # Use password from file if available, otherwise use environment variable
        password_file = values.get("POSTGRES_PASSWORD_FILE")
        password = read_secret_file(password_file) or values.get("POSTGRES_PASSWORD")
        
        return PostgresDsn.build(
            scheme="postgresql+asyncpg",
            username=values.get("POSTGRES_USER"),
            password=password,
            host=values.get("POSTGRES_SERVER"),
            path=values.get("POSTGRES_DB", ""),
        )

    # Redis - Docker secrets support
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: Optional[str] = None
    REDIS_PASSWORD_FILE: Optional[str] = None
    REDIS_DB: int = 0
    REDIS_URL: Optional[str] = None
    
    def get_redis_password(self) -> Optional[str]:
        """Get Redis password from file or environment variable."""
        password_from_file = read_secret_file(self.REDIS_PASSWORD_FILE)
        return password_from_file or self.REDIS_PASSWORD
    
    def get_redis_url(self) -> str:
        """Construct Redis URL with password from secrets if available."""
        if self.REDIS_URL:
            return self.REDIS_URL
        
        password = self.get_redis_password()
        if password:
            return f"redis://:{password}@{self.REDIS_HOST}:{self.REDIS_PORT}/{self.REDIS_DB}"
        else:
            return f"redis://{self.REDIS_HOST}:{self.REDIS_PORT}/{self.REDIS_DB}"
    
    # OAuth2 providers - Docker secrets support
    GOOGLE_CLIENT_ID: Optional[str] = None
    GOOGLE_CLIENT_SECRET: Optional[str] = None
    GOOGLE_CLIENT_SECRET_FILE: Optional[str] = None
    GITHUB_CLIENT_ID: Optional[str] = None
    GITHUB_CLIENT_SECRET: Optional[str] = None
    GITHUB_CLIENT_SECRET_FILE: Optional[str] = None
    
    def get_google_client_secret(self) -> Optional[str]:
        """Get Google client secret from file or environment variable."""
        secret_from_file = read_secret_file(self.GOOGLE_CLIENT_SECRET_FILE)
        return secret_from_file or self.GOOGLE_CLIENT_SECRET
    
    def get_github_client_secret(self) -> Optional[str]:
        """Get GitHub client secret from file or environment variable."""
        secret_from_file = read_secret_file(self.GITHUB_CLIENT_SECRET_FILE)
        return secret_from_file or self.GITHUB_CLIENT_SECRET
    
    # Email
    SMTP_TLS: bool = True
    SMTP_PORT: Optional[int] = 587
    SMTP_HOST: Optional[str] = None
    SMTP_USER: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    EMAILS_FROM_EMAIL: Optional[str] = None
    EMAILS_FROM_NAME: Optional[str] = "NexaNest"
    
    # Rate limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_PER_MINUTE: int = 60
    
    # Session
    SESSION_EXPIRE_MINUTES: int = 60 * 24  # 24 hours
    
    # Superuser
    FIRST_SUPERUSER: str = "admin@nexanest.com"
    FIRST_SUPERUSER_PASSWORD: str = "changeme"
    
    # Service discovery
    SERVICE_NAME: str = "auth-service"
    SERVICE_PORT: int = 8001
    
    # Monitoring
    ENABLE_METRICS: bool = True
    ENABLE_TRACING: bool = True
    JAEGER_HOST: str = "localhost"
    JAEGER_PORT: int = 6831


settings = Settings()