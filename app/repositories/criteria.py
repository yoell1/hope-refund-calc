"""기준값 읽기 (DEDUCTION_TYPE · TAX_BRACKET · BENEFIT_CONDITION) · 읽기 전용.

번호(TYPE_ID)가 아니라 연도 + 코드 + 총급여 구간으로 찾는다 (AGENTS.md 규칙).
계산 코드는 CriteriaSource만 알고, 실제 DB(OracleCriteria)인지 테스트용(InMemoryCriteria)인지 모른다.
"""

from dataclasses import dataclass
from decimal import Decimal
from typing import Protocol

from app.services.bracket import Bracket


@dataclass(frozen=True)
class DeductionType:
    """DEDUCTION_TYPE 1행."""

    tax_year: int
    type_code: str
    type_name: str
    kind: str
    rate: Decimal
    limit_amount: int | None
    salary_min: int
    salary_max: int | None
    category_id: int | None
    pay_method: str | None
    source_note: str

    def covers(self, total_salary: int) -> bool:
        """총급여가 이 행의 구간(SALARY_MIN 초과 ~ SALARY_MAX 이하)에 들어가는지 (SALARY_MIN 0이면 처음부터)."""
        above_min = self.salary_min == 0 or total_salary > self.salary_min
        below_max = self.salary_max is None or total_salary <= self.salary_max
        return above_min and below_max


@dataclass(frozen=True)
class BenefitCondition:
    """BENEFIT_CONDITION 1행."""

    tax_year: int
    benefit_code: str
    benefit_name: str
    min_age: int | None
    max_age: int | None
    max_military_months: int | None
    company_size: str | None
    salary_limit: int | None
    homeless_head_req_yn: str
    reduction_rate: Decimal | None
    limit_amount: int | None
    period_years: int | None
    source_note: str


class CriteriaSource(Protocol):
    def has_year(self, tax_year: int) -> bool: ...

    def deduction_types(self, tax_year: int) -> list[DeductionType]: ...

    def brackets(self, tax_year: int, bracket_type: str) -> list[Bracket]: ...

    def benefit_conditions(self, tax_year: int) -> list[BenefitCondition]: ...


def find_type(source: CriteriaSource, tax_year: int, type_code: str, total_salary: int) -> DeductionType | None:
    """연도 + 코드 + 총급여 구간으로 1행. 구간에 맞는 행이 없으면 None (그 공제를 받을 수 없는 급여)."""
    rows = [t for t in source.deduction_types(tax_year) if t.type_code == type_code and t.covers(total_salary)]
    if len(rows) > 1:
        raise ValueError(f"기준값이 여러 행이에요: {tax_year} {type_code}")
    return rows[0] if rows else None


class InMemoryCriteria:
    """메모리에 든 기준값 (테스트 · DB 없이 계산 확인용)."""

    def __init__(self, types: list[DeductionType], brackets: dict[tuple[int, str], list[Bracket]],
                 benefits: list[BenefitCondition] | None = None):
        self._types = types
        self._brackets = brackets
        self._benefits = benefits or []

    def has_year(self, tax_year: int) -> bool:
        return any(t.tax_year == tax_year for t in self._types)

    def deduction_types(self, tax_year: int) -> list[DeductionType]:
        return [t for t in self._types if t.tax_year == tax_year]

    def brackets(self, tax_year: int, bracket_type: str) -> list[Bracket]:
        return self._brackets.get((tax_year, bracket_type), [])

    def benefit_conditions(self, tax_year: int) -> list[BenefitCondition]:
        return [b for b in self._benefits if b.tax_year == tax_year]
