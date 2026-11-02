"""청년 혜택 자격 진단 (F-12 · 기능명세서 F-03-02).

조건은 BENEFIT_CONDITION 행에서 읽는다 → 혜택을 더 넣을 때 코드를 고치지 않고 DB에 행만 추가.
- 나이: 근로계약 체결일(입사일) 기준 만 나이 − 군 복무(최대 MAX_MILITARY_MONTHS개월) · 노션 「청년 대상」 세법 기준값
- 기간: 입사일부터 PERIOD_YEARS년 안에 귀속 연도가 걸쳐 있는지
- 회사 규모 · 총급여 한도 · 무주택 세대주
판정할 정보가 없으면 eligible=None(판단 불가)과 입력 안내 문구를 돌려준다.
"""

from dataclasses import dataclass, field
from datetime import date

from app.repositories.criteria import BenefitCondition, CriteriaSource
from app.services.errors import NoCriteriaError

COMPANY_LABEL = {"SME": "중소기업", "MID": "중견기업", "LARGE": "대기업"}


@dataclass(frozen=True)
class BenefitInput:
    tax_year: int
    total_salary: int
    birth_date: date
    military_months: int = 0
    hire_date: date | None = None
    company_size: str | None = None
    homeless_head_yn: str = "N"


@dataclass
class BenefitResult:
    benefit_code: str
    benefit_name: str
    eligible: bool | None          # True 해당 · False 비해당 · None 정보 부족
    reasons: list[str] = field(default_factory=list)
    source_note: str = ""


def _age_at(birth: date, at: date, military_months: int) -> int:
    """at 기준 만 나이에서 군 복무 개월을 뺀 나이 (개월로 계산 후 연 단위 내림)."""
    months = (at.year - birth.year) * 12 + (at.month - birth.month) - (1 if at.day < birth.day else 0)
    return (months - military_months) // 12


def _add_years(d: date, years: int) -> date:
    try:
        return d.replace(year=d.year + years)
    except ValueError:  # 2월 29일
        return d.replace(year=d.year + years, day=28)


def _judge(cond: BenefitCondition, data: BenefitInput) -> BenefitResult:
    result = BenefitResult(cond.benefit_code, cond.benefit_name, True, [], cond.source_note)
    unknown: list[str] = []

    if cond.company_size is not None:
        if data.company_size is None:
            unknown.append("회사 규모를 입력하면 진단할 수 있어요")
        elif data.company_size != cond.company_size:
            result.eligible = False
            result.reasons.append(f"{COMPANY_LABEL.get(cond.company_size, cond.company_size)} 재직자만 받을 수 있어요")

    if cond.min_age is not None or cond.max_age is not None:
        if data.hire_date is None:
            unknown.append("입사일을 입력하면 진단할 수 있어요")
        else:
            military = min(max(data.military_months, 0), cond.max_military_months or 0)
            age = _age_at(data.birth_date, data.hire_date, military)
            if cond.min_age is not None and age < cond.min_age:
                result.eligible = False
                result.reasons.append(f"입사 당시 나이가 만 {cond.min_age}세 미만이에요")
            if cond.max_age is not None and age > cond.max_age:
                result.eligible = False
                result.reasons.append(f"입사 당시 나이(군 복무 기간 제외)가 만 {cond.max_age}세를 넘어요")

    if cond.period_years is not None and data.hire_date is not None:
        period_end = _add_years(data.hire_date, cond.period_years)
        if period_end <= date(data.tax_year, 1, 1):
            result.eligible = False
            result.reasons.append(f"입사일부터 {cond.period_years}년이 지났어요")

    if cond.salary_limit is not None and data.total_salary > cond.salary_limit:
        result.eligible = False
        result.reasons.append(f"총급여가 {cond.salary_limit // 10_000:,}만 원을 넘어요")

    if cond.homeless_head_req_yn == "Y" and data.homeless_head_yn != "Y":
        result.eligible = False
        result.reasons.append("무주택 세대주만 받을 수 있어요")

    if result.eligible and unknown:
        result.eligible = None
        result.reasons.extend(unknown)
    return result


def diagnose(source: CriteriaSource, data: BenefitInput) -> list[BenefitResult]:
    conditions = source.benefit_conditions(data.tax_year)
    if not conditions:
        raise NoCriteriaError()
    return [_judge(c, data) for c in conditions]
