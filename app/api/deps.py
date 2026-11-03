"""API 공통 의존성: 기준값 출처 · 호출 토큰 확인."""

import hmac
import logging
import os

from fastapi import Header, HTTPException, Request

from app.repositories.criteria import CriteriaSource

log = logging.getLogger("calc")
_criteria: CriteriaSource | None = None


def get_criteria() -> CriteriaSource:
    """실제 DB 기준값 (테스트에서는 app.dependency_overrides로 바꿔 끼움)."""
    global _criteria
    if _criteria is None:
        from app.repositories.oracle_criteria import OracleCriteria

        _criteria = OracleCriteria()
    return _criteria


def check_token(request: Request, x_calc_token: str | None = Header(default=None)) -> None:
    """이 서버는 Spring 서버만 부른다. .env의 CALC_API_TOKEN과 같은 값을 보낸 요청만 받는다.

    토큰이 설정되지 않았으면 모든 요청을 막는다 (설정을 빠뜨려도 서버가 열린 채로 돌지 않게 · 닫힌 쪽으로 실패).
    """
    expected = os.environ.get("CALC_API_TOKEN")
    if not expected:
        log.error("CALC_API_TOKEN이 설정되지 않아 요청을 막았어요 (.env 확인)")
        raise HTTPException(status_code=503, detail="TOKEN_NOT_SET")
    if not (x_calc_token and hmac.compare_digest(x_calc_token, expected)):
        # 보낸 토큰 값은 남기지 않고, 어디서 왔는지만 남긴다
        log.warning("토큰이 없거나 틀린 요청 차단: %s %s from %s", request.method, request.url.path,
                    request.client.host if request.client else "-")
        raise HTTPException(status_code=401, detail="UNAUTHORIZED")
