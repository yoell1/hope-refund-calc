"""연말정산 예상 세액 계산 (F-03-01 · F-11 항목별 내역).

순서 (노션 「연말정산, 우리 서비스는 뭘 계산하나」 · 기능명세서 F-03-01):
① 총급여 → ② 근로소득공제(구간표 · 최대 2,000만) → ③ 소득공제(인적 · 국민연금 · 건강·고용보험료 · 카드 · 주택청약)
→ ④ 과세표준 × 기본세율 = 산출세액 → ⑤ 감면 · 세액공제(근로소득 · 연금계좌 · 월세 또는 표준세액공제)
→ ⑥ 결정세액 · 환급액 = 기납부세액 − 결정세액 (음수 = 추가 납부)

표준세액공제(13만)는 「건강·고용보험료 소득공제 + 월세 세액공제」를 받지 않을 때만
→ 두 경우를 다 계산해 결정세액이 작은 쪽 (v3.9)
세율·공제율·한도는 모두 DB 기준값에서 읽는다. 코드에 둔 숫자는 tax_rules.py뿐이다.
"""

from dataclasses import dataclass

from app.repositories.criteria import CriteriaSource, DeductionType, find_type
from app.services.bracket import calc_bracket
from app.services.card_deduction import calc_card_deduction
from app.services.errors import NoCriteriaError
from app.services.models import CalcInput, CalcResult, Detail
from app.services.tax_rules import earned_credit_limit, percent_of


@dataclass
class _TaxPart:
    """세액 단계 계산 결과 (표준세액공제를 쓰는 경우 / 안 쓰는 경우 각각)."""

    use_standard: bool
    taxable_income: int
    calculated_tax: int
    applied: dict[str, int]   # 코드 → 실제로 깎은 세액
    decided_tax: int


def _detail(row: DeductionType, base: int, amount: int) -> Detail:
    return Detail(row.type_code, row.type_name, row.kind, base, amount, row.source_note)


def calculate(source: CriteriaSource, data: CalcInput) -> CalcResult:
    year, salary = data.tax_year, data.total_salary
    if not source.has_year(year):
        raise NoCriteriaError()

    def row(code: str) -> DeductionType | None:
        return find_type(source, year, code, salary)

    def required(code: str) -> DeductionType:
        found = row(code)
        if found is None:
            raise NoCriteriaError()
        return found

    details: list[Detail] = []

    # ② 근로소득공제 (최대 금액은 DEDUCTION_TYPE EARNED_DEDUCTION 행의 한도)
    earned_row = required("EARNED_DEDUCTION")
    earned_brackets = source.brackets(year, "EARNED_DEDUCTION")
    if not earned_brackets:
        raise NoCriteriaError()
    earned_deduction = calc_bracket(salary, earned_brackets)
    if earned_row.limit_amount is not None:
        earned_deduction = min(earned_deduction, earned_row.limit_amount)
    earned_income = salary - earned_deduction
    details.append(_detail(earned_row, salary, earned_deduction))

    # ③ 소득공제
    person_row = required("PERSON_BASIC")
    people = 1 + data.dependents
    person = (person_row.limit_amount or 0) * people
    details.append(_detail(person_row, person, person))

    pension_row = required("NATIONAL_PENSION")
    national_pension = percent_of(data.national_pension, pension_row.rate)
    details.append(_detail(pension_row, data.national_pension, national_pension))

    health_row = required("HEALTH_INSURANCE")
    health_full = percent_of(data.health_insurance, health_row.rate)

    housing_row = row("HOUSING_SAVING")  # 총급여 7천만 초과면 행 없음
    housing = 0
    if housing_row is not None and data.homeless_head_yn == "Y":
        housing = percent_of(min(data.housing_saving, housing_row.limit_amount or 0), housing_row.rate)

    card = calc_card_deduction(source, year, salary, data.children, data.card_spends)

    base_income_deduction = person + national_pension + housing + card.total_deduction

    # ④ ~ ⑤ 두 경우 계산
    rate_brackets = source.brackets(year, "TAX_RATE")
    credit_brackets = source.brackets(year, "EARNED_CREDIT")
    if not rate_brackets or not credit_brackets:
        raise NoCriteriaError()
    sme_row = row("SME_YOUTH")
    earned_credit_row = required("EARNED_CREDIT")
    account_row = row("PENSION")
    saving_limit_row = row("PENSION_SAVING_LIMIT")
    rent_row = row("RENT")  # 총급여 8천만 초과면 행 없음
    standard_row = required("STANDARD_CREDIT")

    def tax_part(use_standard: bool) -> _TaxPart:
        income_deduction = base_income_deduction + (0 if use_standard else health_full)
        taxable = max(0, earned_income - income_deduction)
        calculated = calc_bracket(taxable, rate_brackets)
        left = calculated
        applied: dict[str, int] = {}

        def apply(code: str, amount: int) -> None:
            nonlocal left
            used = max(0, min(amount, left))
            applied[code] = used
            left -= used

        # 감면 (중소기업 취업자 · 신청한 경우 · 산출세액 × 90% · 연 200만 한도)
        if sme_row is not None and data.sme_reduction_yn == "Y":
            apply("SME_YOUTH", min(percent_of(calculated, sme_row.rate), sme_row.limit_amount or 0))
        # 근로소득세액공제 (구간표 + 총급여별 한도)
        apply("EARNED_CREDIT", min(calc_bracket(calculated, credit_brackets), earned_credit_limit(salary)))
        # 연금계좌 (연금저축은 단독 600만까지 · IRP 합산 900만 한도)
        if account_row is not None:
            saving = min(data.pension_saving, saving_limit_row.limit_amount) if saving_limit_row and \
                saving_limit_row.limit_amount is not None else data.pension_saving
            account_base = min(saving + data.irp_saving, account_row.limit_amount or 0)
            apply("PENSION", percent_of(account_base, account_row.rate))
        # 월세 또는 표준세액공제
        if use_standard:
            apply("STANDARD_CREDIT", standard_row.limit_amount or 0)
        elif rent_row is not None and data.homeless_head_yn == "Y":
            apply("RENT", percent_of(min(data.monthly_rent * 12, rent_row.limit_amount or 0), rent_row.rate))
        return _TaxPart(use_standard, taxable, calculated, applied, left)

    itemized = tax_part(use_standard=False)
    standard = tax_part(use_standard=True)
    chosen = standard if standard.decided_tax < itemized.decided_tax else itemized

    # 항목별 내역 (선택된 경우 기준)
    details.append(_detail(health_row, data.health_insurance, 0 if chosen.use_standard else health_full))
    if housing_row is not None:
        details.append(_detail(housing_row, data.housing_saving, housing))
    details.extend(card.details)
    if sme_row is not None and data.sme_reduction_yn == "Y":
        details.append(_detail(sme_row, chosen.calculated_tax, chosen.applied.get("SME_YOUTH", 0)))
    details.append(_detail(earned_credit_row, chosen.calculated_tax, chosen.applied.get("EARNED_CREDIT", 0)))
    if account_row is not None:
        details.append(_detail(account_row, data.pension_saving + data.irp_saving, chosen.applied.get("PENSION", 0)))
    if rent_row is not None:
        details.append(_detail(rent_row, data.monthly_rent * 12, chosen.applied.get("RENT", 0)))
    details.append(_detail(standard_row, 0, chosen.applied.get("STANDARD_CREDIT", 0)))

    return CalcResult(
        tax_year=year,
        total_salary=salary,
        withheld_tax=data.withheld_tax,
        taxable_income=chosen.taxable_income,
        calculated_tax=chosen.calculated_tax,
        decided_tax=chosen.decided_tax,
        expected_refund=data.withheld_tax - chosen.decided_tax,
        details=details,
    )
