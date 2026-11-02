"""신용카드 등 소득공제 (조특법 §126의2 · 국세청 신고안내 132p).

1) 사용액을 공제율 항목으로 나눔: 분류(대중교통·전통시장·문화체육) 행이 있으면 그 행, 없으면 일반(결제수단별)
   - 문화체육은 총급여 7천만 이하만 행이 있음 → 초과면 일반으로
   - 공제 행이 하나도 없는 분류(공제 대상 아님)는 뺌
2) 문턱(총급여 × 25%)을 공제율이 낮은 항목부터 뺌 (신용카드 15% → 30% → 40%)
3) 항목별 공제액 = (사용액 − 뺀 문턱) × 공제율
4) 한도: min(합계, 기본한도) + min(기본한도 초과분, 전통시장·대중교통·문화체육 공제액 합, 추가한도)
   - 기본한도는 자녀 수에 따라 CARD_LIMIT_BASE / CHILD1 / CHILD2 (자녀 행이 없는 연도는 BASE)
   - 한도를 넘은 만큼은 기본한도 행에 음수로 → 카드 행을 다 더하면 실제 카드 공제액
"""

from collections import OrderedDict
from dataclasses import dataclass

from app.repositories.criteria import CriteriaSource, DeductionType, find_type
from app.services.errors import NoCriteriaError
from app.services.models import CardSpend, Detail
from app.services.tax_rules import percent_of

GENERAL_CATEGORY_ID = 1  # SPEND_CATEGORY 1 = 일반 (결제수단별 공제율)


@dataclass
class CardResult:
    total_deduction: int
    details: list[Detail]


def _card_rows(source: CriteriaSource, tax_year: int, total_salary: int) -> list[DeductionType]:
    return [t for t in source.deduction_types(tax_year) if t.kind == "CARD" and t.covers(total_salary)]


def _match_row(rows: list[DeductionType], category_id: int, pay_method: str) -> DeductionType | None:
    for row in rows:
        if row.category_id == category_id and (row.pay_method is None or row.pay_method == pay_method):
            return row
    return None


def calc_card_deduction(source: CriteriaSource, tax_year: int, total_salary: int, children: int,
                        spends: list[CardSpend]) -> CardResult:
    rows = _card_rows(source, tax_year, total_salary)
    if not rows:
        raise NoCriteriaError()
    deductible_categories = {t.category_id for t in source.deduction_types(tax_year) if t.kind == "CARD"}

    # 1) 항목별 사용액 (DB 행 순서 유지)
    amounts: "OrderedDict[str, int]" = OrderedDict((r.type_code, 0) for r in rows)
    by_code = {r.type_code: r for r in rows}
    for spend in spends:
        if spend.category_id not in deductible_categories:
            continue  # 공제 대상 아님
        row = _match_row(rows, spend.category_id, spend.pay_method)
        if row is None:  # 예: 총급여 7천만 초과의 문화체육 → 일반(결제수단별)
            row = _match_row(rows, GENERAL_CATEGORY_ID, spend.pay_method)
        if row is not None:
            amounts[row.type_code] += spend.amount
    for code in amounts:
        amounts[code] = max(0, amounts[code])  # 취소가 더 많으면 0

    # 2) 문턱을 공제율 낮은 항목부터
    threshold_row = find_type(source, tax_year, "CARD_THRESHOLD", total_salary)
    if threshold_row is None:
        raise NoCriteriaError()
    threshold_left = percent_of(total_salary, threshold_row.rate)
    deductions: dict[str, int] = {}
    for code in sorted(amounts, key=lambda c: by_code[c].rate):
        used = min(amounts[code], threshold_left)
        threshold_left -= used
        deductions[code] = percent_of(amounts[code] - used, by_code[code].rate)

    # 3) 한도
    gross = sum(deductions.values())
    special = sum(v for c, v in deductions.items() if by_code[c].category_id != GENERAL_CATEGORY_ID)
    limit_code = "CARD_LIMIT_BASE"
    if children >= 2 and find_type(source, tax_year, "CARD_LIMIT_CHILD2", total_salary):
        limit_code = "CARD_LIMIT_CHILD2"
    elif children == 1 and find_type(source, tax_year, "CARD_LIMIT_CHILD1", total_salary):
        limit_code = "CARD_LIMIT_CHILD1"
    base_limit_row = find_type(source, tax_year, limit_code, total_salary)
    extra_limit_row = find_type(source, tax_year, "CARD_LIMIT_EXTRA", total_salary)
    if base_limit_row is None or extra_limit_row is None:
        raise NoCriteriaError()
    base_limit = base_limit_row.limit_amount or 0
    extra_limit = extra_limit_row.limit_amount or 0
    allowed = min(gross, base_limit) + min(max(gross - base_limit, 0), special, extra_limit)
    over = gross - allowed

    details = [
        Detail(code, by_code[code].type_name, by_code[code].kind, amounts[code], deductions[code],
               by_code[code].source_note)
        for code in amounts
    ]
    if over > 0:
        details.append(Detail(base_limit_row.type_code, base_limit_row.type_name, base_limit_row.kind,
                              gross, -over, base_limit_row.source_note))
    return CardResult(total_deduction=allowed, details=details)
