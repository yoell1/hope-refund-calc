"""DB에서 기준값 읽기 (읽기 전용 · 값은 바인드 변수로만 넣는다)."""

import logging
import time
from decimal import Decimal

from app.db.oracle import get_pool
from app.repositories.criteria import BenefitCondition, DeductionType
from app.services.bracket import Bracket

log = logging.getLogger("calc")


def _int(value) -> int | None:
    return None if value is None else int(value)


# 기준값을 메모리에 들고 있는 시간(초). 관리자가 기준값을 고치면(F-08-01) 늦어도 이 시간 뒤에는 새 값으로 계산한다.
CACHE_SECONDS = 300


class OracleCriteria:
    """CriteriaSource 구현. 읽은 기준값을 CACHE_SECONDS 동안 메모리에 두고, 지나면 DB에서 다시 읽는다."""

    def __init__(self, cache_seconds: float = CACHE_SECONDS, clock=time.monotonic):
        self._cache_seconds = cache_seconds
        self._clock = clock
        self._cache: dict[tuple, tuple[float, list]] = {}

    def _cached(self, key: tuple, load) -> list:
        """key가 없거나 오래됐으면 load()로 다시 읽는다."""
        now = self._clock()
        hit = self._cache.get(key)
        if hit is None or now - hit[0] >= self._cache_seconds:
            log.info("기준값 DB에서 읽음 %s", key)
            hit = (now, load())
            self._cache[key] = hit
        return hit[1]

    def _query(self, sql: str, **params) -> list[tuple]:
        with get_pool().acquire() as conn, conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()

    def has_year(self, tax_year: int) -> bool:
        return bool(self.deduction_types(tax_year))

    def deduction_types(self, tax_year: int) -> list[DeductionType]:
        def load() -> list[DeductionType]:
            rows = self._query(
                "SELECT TAX_YEAR, TYPE_CODE, TYPE_NAME, DEDUCTION_KIND, RATE, LIMIT_AMOUNT, SALARY_MIN, SALARY_MAX,"
                " CATEGORY_ID, PAY_METHOD, SOURCE_NOTE FROM DEDUCTION_TYPE WHERE TAX_YEAR = :y ORDER BY TYPE_ID",
                y=tax_year,
            )
            return [
                DeductionType(int(r[0]), r[1], r[2], r[3], Decimal(str(r[4])), _int(r[5]), int(r[6]), _int(r[7]),
                              _int(r[8]), r[9], r[10] or "")
                for r in rows
            ]

        return self._cached(("types", tax_year), load)

    def brackets(self, tax_year: int, bracket_type: str) -> list[Bracket]:
        def load() -> list[Bracket]:
            rows = self._query(
                "SELECT LOWER_AMOUNT, UPPER_AMOUNT, RATE, BASE_AMOUNT FROM TAX_BRACKET"
                " WHERE TAX_YEAR = :y AND BRACKET_TYPE = :t ORDER BY LOWER_AMOUNT",
                y=tax_year, t=bracket_type,
            )
            return [Bracket(int(r[0]), _int(r[1]), Decimal(str(r[2])), int(r[3])) for r in rows]

        return self._cached(("brackets", tax_year, bracket_type), load)

    def benefit_conditions(self, tax_year: int) -> list[BenefitCondition]:
        def load() -> list[BenefitCondition]:
            rows = self._query(
                "SELECT TAX_YEAR, BENEFIT_CODE, BENEFIT_NAME, MIN_AGE, MAX_AGE, MAX_MILITARY_MONTHS, COMPANY_SIZE,"
                " SALARY_LIMIT, HOMELESS_HEAD_REQ_YN, REDUCTION_RATE, LIMIT_AMOUNT, PERIOD_YEARS, SOURCE_NOTE"
                " FROM BENEFIT_CONDITION WHERE TAX_YEAR = :y ORDER BY BENEFIT_ID",
                y=tax_year,
            )
            return [
                BenefitCondition(int(r[0]), r[1], r[2], _int(r[3]), _int(r[4]), _int(r[5]), r[6], _int(r[7]), r[8],
                                 None if r[9] is None else Decimal(str(r[9])), _int(r[10]), _int(r[11]), r[12] or "")
                for r in rows
            ]

        return self._cached(("benefits", tax_year), load)
