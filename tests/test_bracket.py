from app.services.bracket import calc_bracket
from tests.criteria_data import BRACKETS


def test_근로소득공제_3천만():
    # 750만 + (3,000만 − 1,500만) × 15% (노션 「한 장 요약」 예시)
    assert calc_bracket(30_000_000, BRACKETS[(2026, "EARNED_DEDUCTION")]) == 9_750_000


def test_산출세액_과세표준_1537만5천():
    # 84만 + (1,537.5만 − 1,400만) × 15%
    assert calc_bracket(15_375_000, BRACKETS[(2026, "TAX_RATE")]) == 1_046_250


def test_근로소득세액공제_130만_이하는_55퍼센트_원미만_버림():
    assert calc_bracket(1_046_250, BRACKETS[(2026, "EARNED_CREDIT")]) == 575_437


def test_구간_경계는_이하쪽():
    # 1,400만은 첫 구간(이하) → 6%
    assert calc_bracket(14_000_000, BRACKETS[(2026, "TAX_RATE")]) == 840_000


def test_0원이면_0():
    assert calc_bracket(0, BRACKETS[(2026, "TAX_RATE")]) == 0
