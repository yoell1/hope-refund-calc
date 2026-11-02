"""Oracle 연결. 접속 정보는 .env에서만 읽는다 (DB_USERNAME · DB_PASSWORD · DB_DSN)."""

import os

import oracledb

_pool: oracledb.ConnectionPool | None = None


def get_pool() -> oracledb.ConnectionPool:
    global _pool
    if _pool is None:
        _pool = oracledb.create_pool(
            user=os.environ["DB_USERNAME"],
            password=os.environ["DB_PASSWORD"],
            dsn=os.environ["DB_DSN"],  # 예: 주소:포트/서비스이름
            min=1,
            max=4,
        )
    return _pool
