from app.services.card_deduction import calc_card_deduction
from app.services.models import CardSpend
from tests.criteria_data import criteria

GENERAL, TRANSIT, MARKET, CULTURE, EXCLUDED = 1, 2, 3, 4, 5


def _calc(salary, spends, children=0, year=2026):
    return calc_card_deduction(criteria(), year, salary, children, spends)


def _row(result, code):
    return next(d for d in result.details if d.type_code == code)


def test_문턱을_넘은_부분만_공제():
    # (1,200만 − 문턱 750만) × 15% (노션 「한 장 요약」 예시)
    result = _calc(30_000_000, [CardSpend(GENERAL, "CREDIT", 12_000_000)])
    assert result.total_deduction == 675_000


def test_문턱은_신용카드부터_뺀다():
    # 문턱 750만: 신용 500만 전부 + 체크 250만 → 체크 250만 × 30%
    result = _calc(30_000_000, [CardSpend(GENERAL, "CREDIT", 5_000_000), CardSpend(GENERAL, "CHECK", 5_000_000)])
    assert _row(result, "CARD_CREDIT").deduction_amount == 0
    assert _row(result, "CARD_CHECK").deduction_amount == 750_000


def test_카드_행은_6개():
    result = _calc(30_000_000, [])
    assert len([d for d in result.details if d.kind == "CARD"]) == 6


def test_기본한도를_넘으면_한도_행이_음수():
    # (4,000만 − 750만) × 15% = 487.5만 → 기본한도 300만 → 187.5만 초과
    result = _calc(30_000_000, [CardSpend(GENERAL, "CREDIT", 40_000_000)])
    assert result.total_deduction == 3_000_000
    assert _row(result, "CARD_LIMIT_BASE").deduction_amount == -1_875_000


def test_카드_행을_다_더하면_실제_공제액():
    result = _calc(30_000_000, [CardSpend(GENERAL, "CREDIT", 40_000_000), CardSpend(TRANSIT, "CREDIT", 10_000_000)])
    assert sum(d.deduction_amount for d in result.details) == result.total_deduction


def test_대중교통은_추가한도까지_더_받는다():
    # 일반 487.5만 + 대중교통 400만 = 887.5만 → 300만 + min(587.5만, 400만, 추가한도 300만) = 600만
    result = _calc(30_000_000, [CardSpend(GENERAL, "CREDIT", 40_000_000), CardSpend(TRANSIT, "CREDIT", 10_000_000)])
    assert result.total_deduction == 6_000_000


def test_2026년은_자녀_1명이면_기본한도_350만():
    result = _calc(30_000_000, [CardSpend(GENERAL, "CREDIT", 40_000_000)], children=1)
    assert result.total_deduction == 3_500_000


def test_2025년은_자녀가_있어도_기본한도_300만():
    result = _calc(30_000_000, [CardSpend(GENERAL, "CREDIT", 40_000_000)], children=1, year=2025)
    assert result.total_deduction == 3_000_000


def test_총급여_7천만_초과면_문화체육은_일반으로():
    # 문턱 2,000만(8,000만 × 25%) · 문화체육 2,500만(체크) → 체크카드(일반) 행으로 → 500만 × 30%
    result = _calc(80_000_000, [CardSpend(CULTURE, "CHECK", 25_000_000)])
    assert _row(result, "CARD_CHECK").deduction_amount == 1_500_000


def test_공제_대상_아님은_뺀다():
    result = _calc(30_000_000, [CardSpend(EXCLUDED, "CREDIT", 50_000_000)])
    assert result.total_deduction == 0
