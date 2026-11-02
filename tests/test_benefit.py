from datetime import date

from app.services.benefit import BenefitInput, diagnose
from tests.criteria_data import criteria


def _result(results, code):
    return next(r for r in results if r.benefit_code == code)


def _input(**overrides):
    values = dict(tax_year=2026, total_salary=30_000_000, birth_date=date(1995, 5, 10), hire_date=date(2023, 3, 1),
                  company_size="SME", homeless_head_yn="Y")
    values.update(overrides)
    return BenefitInput(**values)


def test_조건을_다_맞으면_중소기업_감면_해당():
    assert _result(diagnose(criteria(), _input()), "SME_YOUTH").eligible is True


def test_군_복무_기간만큼_나이를_빼준다():
    # 입사 당시 만 35세 − 군 복무 24개월 → 33세
    data = _input(birth_date=date(1990, 1, 1), hire_date=date(2025, 3, 1), military_months=24)
    assert _result(diagnose(criteria(), data), "SME_YOUTH").eligible is True


def test_군_복무는_72개월까지만_인정():
    # 입사 당시 만 42세 − 최대 72개월 → 36세 → 비해당
    data = _input(birth_date=date(1983, 1, 1), hire_date=date(2025, 3, 1), military_months=100)
    assert _result(diagnose(criteria(), data), "SME_YOUTH").eligible is False


def test_대기업이면_비해당과_이유():
    result = _result(diagnose(criteria(), _input(company_size="LARGE")), "SME_YOUTH")
    assert result.eligible is False
    assert "중소기업 재직자만 받을 수 있어요" in result.reasons


def test_회사_규모가_없으면_판단_불가():
    result = _result(diagnose(criteria(), _input(company_size=None)), "SME_YOUTH")
    assert result.eligible is None
    assert "회사 규모를 입력하면 진단할 수 있어요" in result.reasons


def test_입사일부터_5년이_지나면_비해당():
    assert _result(diagnose(criteria(), _input(hire_date=date(2020, 1, 1))), "SME_YOUTH").eligible is False


def test_무주택_세대주가_아니면_월세_비해당():
    result = _result(diagnose(criteria(), _input(homeless_head_yn="N")), "RENT")
    assert result.eligible is False


def test_총급여_7천만_초과면_주택청약_비해당():
    assert _result(diagnose(criteria(), _input(total_salary=75_000_000)), "HOUSING_SAVING").eligible is False
