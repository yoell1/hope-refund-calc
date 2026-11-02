"""/calculate 요청·응답 (응답 이름은 노션 「동석님 전달」 그대로)."""

from typing import Literal

from pydantic import Field

from app.schemas.common import CamelModel

YN = Literal["Y", "N"]
MAX_AMOUNT = 999_999_999_999  # NUMBER(12)


class CardSpendRequest(CamelModel):
    category_id: int = Field(ge=1)
    pay_method: Literal["CREDIT", "CHECK", "CASH"]
    amount: int = Field(ge=-MAX_AMOUNT, le=MAX_AMOUNT)  # 취소가 많으면 음수 합계도 올 수 있음


class CalcRequest(CamelModel):
    tax_year: int = Field(ge=2000, le=2100)
    total_salary: int = Field(ge=0, le=MAX_AMOUNT)
    withheld_tax: int = Field(ge=0, le=MAX_AMOUNT)
    national_pension: int = Field(default=0, ge=0, le=MAX_AMOUNT)
    health_insurance: int = Field(default=0, ge=0, le=MAX_AMOUNT)
    dependents: int = Field(default=0, ge=0, le=99)
    children: int = Field(default=0, ge=0, le=99)
    monthly_rent: int = Field(default=0, ge=0, le=MAX_AMOUNT)
    housing_saving: int = Field(default=0, ge=0, le=MAX_AMOUNT)
    pension_saving: int = Field(default=0, ge=0, le=MAX_AMOUNT)
    irp_saving: int = Field(default=0, ge=0, le=MAX_AMOUNT)
    sme_reduction_yn: YN = "N"
    homeless_head_yn: YN = "N"
    card_spends: list[CardSpendRequest] = Field(default_factory=list, max_length=100)


class DetailResponse(CamelModel):
    type_code: str
    type_name: str
    kind: str
    base_amount: int
    deduction_amount: int
    source_note: str


class CalcResponse(CamelModel):
    tax_year: int
    total_salary: int
    withheld_tax: int
    taxable_income: int
    calculated_tax: int
    decided_tax: int
    expected_refund: int
    details: list[DetailResponse]
