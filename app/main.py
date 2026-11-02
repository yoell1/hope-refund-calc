"""FastAPI 시작 · 계산 서버 (Spring 서버만 부름).

실행: uvicorn app.main:app --reload --port 8000 (.env를 읽음)
오류 응답은 {"error", "message"} 모양 · 원인(스택 트레이스·DB 정보)은 서버 로그에만.
"""

import logging
import os

from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException

from app.api import benefit, calculate
from app.services.errors import NoCriteriaError

load_dotenv()
log = logging.getLogger("calc")
if not os.environ.get("CALC_API_TOKEN"):
    log.error("CALC_API_TOKEN이 비어 있어요. .env에 넣기 전까지 모든 계산 요청을 막아요")

app = FastAPI(title="희망환급 계산 서버", docs_url=None, redoc_url=None, openapi_url=None)
app.include_router(calculate.router)
app.include_router(benefit.router)


def _error(status: int, error: str, message: str) -> JSONResponse:
    return JSONResponse(status_code=status, content={"error": error, "message": message})


@app.exception_handler(NoCriteriaError)
def no_criteria(_: Request, e: NoCriteriaError) -> JSONResponse:
    return _error(400, "NO_CRITERIA", e.message)


@app.exception_handler(RequestValidationError)
def invalid(_: Request, e: RequestValidationError) -> JSONResponse:
    return _error(400, "VALIDATION", "입력값을 확인해 주세요")


@app.exception_handler(HTTPException)
def http_error(_: Request, e: HTTPException) -> JSONResponse:
    if e.status_code == 401:
        return _error(401, "UNAUTHORIZED", "허용되지 않은 요청이에요")
    if e.status_code == 503:
        return _error(503, "TOKEN_NOT_SET", "계산 서버 설정이 끝나지 않았어요")
    return _error(e.status_code, "HTTP_ERROR", "요청을 처리할 수 없어요")


@app.exception_handler(Exception)
def unexpected(_: Request, e: Exception) -> JSONResponse:
    log.exception("처리하지 못한 오류")
    return _error(500, "SERVER_ERROR", "잠시 후 다시 시도해 주세요")
