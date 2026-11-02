"""DB에서 기준값 읽기 (읽기 전용 · 값은 바인드 변수로만 넣는다)."""

from decimal import Decimal

from app.db.oracle import get_pool
from app.repositories.criteria import BenefitCondition, DeductionType
from app.services.bracket import Bracket


def _int(value) -> int | None:
    return None if value is None else int(value)


class OracleCriteria:
    """CriteriaSource 구현. 연도별로 한 번 읽어 메모리에 둔다 (기준값은 자주 안 바뀜 · 서버 재시작 시 다시 읽음)."""

    def __init__(self):
        self._types: dict[int, list[DeductionType]] = {}
        self._brackets: dict[tuple[int, str], list[Bracket]] = {}
        self._benefits: dict[int, list[BenefitCondition]] = {}

    def _query(self, sql: str, **params) -> list[tuple]:
        with get_pool().acquire() as conn, conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()

    def has_year(self, tax_year: int) -> bool:
        return bool(self.deduction_types(tax_year))

    def deduction_types(self, tax_year: int) -> list[DeductionType]:
        if tax_year not in self._types:
            rows = self._query(
                "SELECT TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MIN, SALARY_MAX,"
                " CATEGORY_ID, PAY_METHOD, SOURCE_NOTE FROM DEDUCTION_TYPE WHERE TAX_YEAR = :y ORDER BY TYPE_ID",
                y=tax_year,
            )
            self._types[tax_year] = [
                DeductionType(int(r[0]), r[1], r[2], r[3], Decimal(str(r[4])), _int(r[5]), int(r[6]), _int(r[7]),
                              _int(r[8]), r[9], r[10] or "")
                for r in rows
            ]
        return self._types[tax_year]

    def brackets(self, tax_year: int, bracket_type: str) -> list[Bracket]:
        key = (tax_year, bracket_type)
        if key not in self._brackets:
            rows = self._query(
                "SELECT LOWER_AMOUNT, UPPER_AMOUNT, RATE, BASE_AMOUNT FROM TAX_BRACKET"
                " WHERE TAX_YEAR = :y AND BRACKET_TYPE = :t ORDER BY LOWER_AMOUNT",
                y=tax_year, t=bracket_type,
            )
            self._brackets[key] = [Bracket(int(r[0]), _int(r[1]), Decimal(str(r[2])), int(r[3])) for r in rows]
        return self._brackets[key]

    def benefit_conditions(self, tax_year: int) -> list[BenefitCondition]:
        if tax_year not in self._benefits:
            rows = self._query(
                "SELECT TAX_YEAR, BENEFIT_CODE, BENEFIT_NAME, MIN_AGE, MAX_AGE, MAX_MILITARY_MONTHS, COMPANY_SIZE,"
                " SALARY_LIMIT, HOMELESS_HEAD_REQ_YN, REDUCTION_RATE, LIMIT_AMOUNT, PERIOD_YEARS, SOURCE_NOTE"
                " FROM BENEFIT_CONDITION WHERE TAX_YEAR = :y ORDER BY BENEFIT_ID",
                y=tax_year,
            )
            self._benefits[tax_year] = [
                BenefitCondition(int(r[0]), r[1], r[2], _int(r[3]), _int(r[4]), _int(r[5]), r[6], _int(r[7]), r[8],
                                 None if r[9] is None else Decimal(str(r[9])), _int(r[10]), _int(r[11]), r[12] or "")
                for r in rows
            ]
        return self._benefits[tax_year]
