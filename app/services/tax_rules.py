"""세법 숫자 중 DB 구간표에 넣지 않고 코드에 둔 것 (11/02 결정 · 노션 「청년 대상 - 공제 항목 및 기능 정리」 구간표 D).

- 근로소득세액공제 총급여별 한도: max() 조건이 있어 TAX_BRACKET 형식에 안 맞음 (국세청 신고안내 162p · 소득세법 §59)
- 원 미만 처리: 원 미만 버림 (멘토링에서 확정 전 · 바뀌면 floor_won 하나만 고치면 됨)
- 감면을 받을 때 근로소득세액공제 줄이기: 국세청 「중소기업 취업자 소득세 감면제도 안내」(2023.6) p.10~12
"""

from decimal import ROUND_FLOOR, Decimal


def floor_won(value) -> int:
    """원 미만 버림. 금액 계산 결과는 모두 이 함수를 거쳐 정수로 만든다."""
    return int(Decimal(str(value)).to_integral_value(rounding=ROUND_FLOOR))


def percent_of(amount: int, rate) -> int:
    """amount × rate% (원 미만 버림). rate는 DB RATE 값(15 = 15%)."""
    return floor_won(Decimal(amount) * Decimal(str(rate)) / Decimal(100))


def earned_credit_limit(total_salary: int) -> int:
    """근로소득세액공제 한도 (총급여 기준 · 책자 162p).

    3,300만 이하 74만 / 7천만 이하 max(66만, 74만 - (총급여 - 3,300만) × 0.8%)
    1.2억 이하 max(50만, 66만 - (총급여 - 7천만) × 1/2) / 초과 max(20만, 50만 - (총급여 - 1.2억) × 1/2)

    ※ 이 한도는 DB가 아니라 코드에 있어요 → 관리자 화면(F-08-01)으로는 못 바꿔요.
       「최소값 + 기울기」 계산식이라 지금 DB 칸(공제율 · 한도 · 구간)으로 표현할 수 없어서예요.
    ※ 연도를 구분하지 않아요 (2025 · 2026 귀속은 같은 규칙).
       법이 바뀌면 이 함수를 그냥 고치지 말고 귀속 연도를 받아 연도별로 나눠서 고쳐야 해요.
       그대로 고치면 이미 지난 연도(2025 · 2026) 계산 결과까지 바뀌어요.
    """
    if total_salary <= 33_000_000:
        return 740_000
    if total_salary <= 70_000_000:
        return max(660_000, 740_000 - floor_won(Decimal(total_salary - 33_000_000) * Decimal("0.008")))
    if total_salary <= 120_000_000:
        return max(500_000, 660_000 - floor_won(Decimal(total_salary - 70_000_000) / 2))
    return max(200_000, 500_000 - floor_won(Decimal(total_salary - 120_000_000) / 2))


def earned_credit_after_reduction(credit_before: int, reduction: int, calculated_tax: int) -> int:
    """세액감면을 받을 때 근로소득세액공제 (원 미만 버림).

    감면 적용 전 근로소득세액공제 × (1 − 감면세액 ÷ 산출세액)
    근거: 국세청 「중소기업 취업자 소득세 감면제도 안내」(2023.6) p.10 계산식 · p.11~12 계산 사례
    예) 716,000 × (1 − 1,748,250 ÷ 1,942,500) = 71,600
    """
    if reduction <= 0 or calculated_tax <= 0:
        return credit_before
    return credit_before * (calculated_tax - reduction) // calculated_tax
