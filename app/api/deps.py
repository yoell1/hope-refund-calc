"""API 공통 의존성: 기준값 출처 · 호출 토큰 확인."""

import hmac
import os

from fastapi import Header, HTTPException

from app.repositories.criteria import CriteriaSource

_criteria: CriteriaSource | None = None


def get_criteria() -> CriteriaSource:
    """실제 DB 기준값 (테스트에서는 app.dependency_overrides로 바꿔 끼움)."""
    global _criteria
    if _criteria is None:
        from app.repositories.oracle_criteria import OracleCriteria

        _criteria = OracleCriteria()
    return _criteria


def check_token(x_calc_token: str | None = Header(default=None)) -> None:
    """이 서버는 Spring 서버만 부른다. .env의 CALC_API_TOKEN이 있으면 같은 값을 보낸 요청만 받는다."""
    expected = os.environ.get("CALC_API_TOKEN")
    if expected and not (x_calc_token and hmac.compare_digest(x_calc_token, expected)):
        raise HTTPException(status_code=401, detail="UNAUTHORIZED")
