import pytest

from app.services.errors import NoCriteriaError
from app.services.models import CalcInput, CardSpend
from app.services.tax_calculator import calculate
from tests.criteria_data import criteria


def _row(result, code):
    return next(d for d in result.details if d.type_code == code)


def _example(**overrides):
    # 노션 「한 장 요약」 예시: 총급여 3,000만 · 본인 1명 · 사회보험료 270만 · 신용카드 1,200만 · 기납부세액 60만
    values = dict(tax_year=2026, total_salary=30_000_000, withheld_tax=600_000, national_pension=2_700_000,
                  card_spends=[CardSpend(1, "CREDIT", 12_000_000)])
    values.update(overrides)
    return CalcInput(**values)


def test_예시의_과세표준과_산출세액():
    result = calculate(criteria(), _example())
    assert result.taxable_income == 15_375_000
    assert result.calculated_tax == 1_046_250


def test_예시의_근로소득세액공제():
    result = calculate(criteria(), _example())
    assert _row(result, "EARNED_CREDIT").deduction_amount == 575_437


def test_국민연금만_있으면_표준세액공제_13만을_받는다():
    # 결정세액 = 1,046,250 − 575,437 − 130,000
    result = calculate(criteria(), _example())
    assert result.decided_tax == 340_813
    assert result.expected_refund == 600_000 - 340_813


def test_건강보험료_공제가_유리하면_표준세액공제를_안_받는다():
    # 건강·고용보험료 270만 소득공제 쪽 결정세액 470,813 < 표준세액공제 쪽 581,250
    result = calculate(criteria(), _example(national_pension=0, health_insurance=2_700_000))
    assert result.decided_tax == 470_813
    assert _row(result, "STANDARD_CREDIT").deduction_amount == 0
    assert _row(result, "HEALTH_INSURANCE").deduction_amount == 2_700_000


def test_무주택_세대주는_월세_세액공제():
    # 월 50만 × 12 = 600만 × 17% = 102만 (결정세액 안에서)
    result = calculate(criteria(), _example(total_salary=50_000_000, withheld_tax=3_000_000, monthly_rent=500_000,
                                            homeless_head_yn="Y", health_insurance=1_000_000))
    assert _row(result, "RENT").deduction_amount == 1_020_000


def test_무주택_세대주가_아니면_월세_공제_없음():
    result = calculate(criteria(), _example(monthly_rent=500_000, homeless_head_yn="N"))
    assert _row(result, "RENT").deduction_amount == 0


def test_연금저축은_600만까지만():
    # 연금저축 800만 → 600만 + IRP 300만 = 900만 × 15% = 135만 (총급여 5,500만 이하)
    result = calculate(criteria(), _example(total_salary=50_000_000, withheld_tax=5_000_000,
                                            pension_saving=8_000_000, irp_saving=3_000_000))
    assert _row(result, "PENSION").deduction_amount == 1_350_000


def test_중소기업_감면은_산출세액의_90퍼센트_200만_한도():
    result = calculate(criteria(), _example(total_salary=60_000_000, withheld_tax=5_000_000, sme_reduction_yn="Y"))
    reduction = _row(result, "SME_YOUTH").deduction_amount
    assert reduction == min(result.calculated_tax * 90 // 100, 2_000_000)


def test_감면을_받으면_근로소득세액공제가_감면비율만큼_줄어든다():
    # 국세청 「중소기업 취업자 소득세 감면제도 안내」(2023.6) p.10: 감면 전 공제 × (1 − 감면세액 ÷ 산출세액)
    base = calculate(criteria(), _example(total_salary=36_000_000, withheld_tax=2_000_000))
    sme = calculate(criteria(), _example(total_salary=36_000_000, withheld_tax=2_000_000, sme_reduction_yn="Y"))
    before = _row(base, "EARNED_CREDIT").deduction_amount
    reduction = _row(sme, "SME_YOUTH").deduction_amount
    credit = _row(sme, "EARNED_CREDIT").deduction_amount
    assert credit == before * (sme.calculated_tax - reduction) // sme.calculated_tax
    assert credit < before


def test_세액공제는_산출세액을_넘지_않는다():
    result = calculate(criteria(), _example(total_salary=20_000_000, withheld_tax=0, pension_saving=6_000_000))
    assert result.decided_tax == 0


def test_더_적게_냈으면_환급액이_음수():
    result = calculate(criteria(), _example(withheld_tax=0))
    assert result.expected_refund < 0


def test_총급여_8천만_초과면_월세_행이_없다():
    result = calculate(criteria(), _example(total_salary=90_000_000, withheld_tax=10_000_000))
    assert all(d.type_code != "RENT" for d in result.details)


def test_기준값이_없는_연도는_계산하지_않는다():
    with pytest.raises(NoCriteriaError):
        calculate(criteria(), _example(tax_year=2024))
