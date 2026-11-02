import pytest

from app.services.tax_rules import earned_credit_limit, floor_won, percent_of


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
