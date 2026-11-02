"""/benefit 요청·응답 (청년 혜택 자격 진단)."""

from datetime import date
from typing import Literal

from pydantic import Field

from app.schemas.common import CamelModel


class BenefitRequest(CamelModel):
    tax_year: int = Field(ge=2000, le=2100)
    total_salary: int = Field(ge=0, le=999_999_999_999)
    birth_date: date
    military_months: int = Field(default=0, ge=0, le=999)
    hire_date: date | None = None
    company_size: Literal["SME", "MID", "LARGE"] | None = None
    homeless_head_yn: Literal["Y", "N"] = "N"


class BenefitResultResponse(CamelModel):
    benefit_code: str
    benefit_name: str
    eligible: bool | None
    reasons: list[str]
    source_note: str


class BenefitResponse(CamelModel):
    tax_year: int
    results: list[BenefitResultResponse]
