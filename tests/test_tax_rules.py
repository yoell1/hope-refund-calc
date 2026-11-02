import pytest

from app.services.tax_rules import earned_credit_after_reduction, earned_credit_limit, floor_won, percent_of


def test_원_미만_버림():
    assert floor_won(575_437.5) == 575_437


def test_퍼센트_계산():
    assert percent_of(4_500_000, 15) == 675_000


@pytest.mark.parametrize(
    ("salary", "limit"),
    [
        (30_000_000, 740_000),    # 3,300만 이하
        (40_000_000, 684_000),    # 74만 − 700만 × 0.8%
        (50_000_000, 660_000),    # 최소 66만
        (80_000_000, 500_000),    # 최소 50만
        (130_000_000, 200_000),   # 최소 20만
    ],
)
def test_근로소득세액공제_한도(salary, limit):
    assert earned_credit_limit(salary) == limit


def test_감면을_받으면_근로소득세액공제를_감면비율만큼_줄인다():
    # 국세청 「중소기업 취업자 소득세 감면제도 안내」(2023.6) p.11~12 계산 사례 숫자 그대로
    assert earned_credit_after_reduction(716_000, 1_748_250, 1_942_500) == 71_600
    assert earned_credit_after_reduction(660_000, 2_000_000, 3_802_500) == 312_859
    assert earned_credit_after_reduction(660_000, 1_368_900, 3_802_500) == 422_400


def test_감면이_없으면_근로소득세액공제_그대로():
    assert earned_credit_after_reduction(716_000, 0, 1_942_500) == 716_000
