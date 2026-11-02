"""구간 계산 하나로 통일 (AGENTS.md 규칙): 결과 = 기본 금액 + (금액 − 구간 시작) × 비율 ÷ 100

근로소득공제 · 기본세율(산출세액) · 근로소득세액공제가 모두 이 함수를 쓴다. 관리자 미리보기도 같은 함수를 쓴다.
"""

from dataclasses import dataclass
from decimal import Decimal

from app.services.tax_rules import floor_won


@dataclass(frozen=True)
class Bracket:
    """TAX_BRACKET 1행. lower 초과 ~ upper 이하 (upper가 None이면 상한 없음)."""

    lower: int
    upper: int | None
    rate: Decimal
    base: int


def calc_bracket(amount: int, brackets: list[Bracket]) -> int:
    """amount가 들어가는 구간을 찾아 계산한다. 0 이하이면 0."""
    if amount <= 0:
        return 0
    for b in sorted(brackets, key=lambda x: x.lower):
        if amount > b.lower and (b.upper is None or amount <= b.upper):
            return b.base + floor_won(Decimal(amount - b.lower) * b.rate / Decimal(100))
    raise ValueError(f"구간을 찾을 수 없어요: {amount}")
