"""계산 입력·결과 (서비스 계층용 · API 모양은 app/schemas)."""

from dataclasses import dataclass, field


@dataclass(frozen=True)
class CardSpend:
    """카드 사용 합계 1줄: 분류(SPEND_CATEGORY.CATEGORY_ID) + 결제수단(CREDIT/CHECK/CASH)별 금액 합.

    취소 건은 음수로 이미 빠진 값이다.
    """

    category_id: int
    pay_method: str
    amount: int


@dataclass(frozen=True)
class CalcInput:
    tax_year: int
    total_salary: int
    withheld_tax: int
    national_pension: int = 0
    health_insurance: int = 0
    dependents: int = 0           # 부양가족 수 (본인 제외)
    children: int = 0             # 20세 이하 자녀 수 (카드 기본한도 자녀 가산)
    monthly_rent: int = 0         # 월 월세액 (계산 때 × 12)
    housing_saving: int = 0       # 주택청약 연 납입액
    pension_saving: int = 0       # 연금저축 연 납입액
    irp_saving: int = 0           # IRP 연 납입액
    sme_reduction_yn: str = "N"   # 중소기업 취업자 감면 신청
    homeless_head_yn: str = "N"   # 무주택 세대주 (MEMBER)
    card_spends: list[CardSpend] = field(default_factory=list)


@dataclass
class Detail:
    """항목별 공제 내역 1행 (노션 「동석님 전달」 details[])."""

    type_code: str
    type_name: str
    kind: str
    base_amount: int
    deduction_amount: int
    source_note: str


@dataclass
class CalcResult:
    tax_year: int
    total_salary: int
    withheld_tax: int
    taxable_income: int
    calculated_tax: int
    decided_tax: int
    expected_refund: int
    details: list[Detail]
