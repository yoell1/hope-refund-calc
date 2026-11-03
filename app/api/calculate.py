"""POST /calculate · 계산만 하고 저장하지 않는다 (저장은 Spring prediction/)."""

import logging
import time
from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import check_token, get_criteria
from app.repositories.criteria import CriteriaSource
from app.schemas.calculation import CalcRequest, CalcResponse, DetailResponse
from app.services.models import CalcInput, CardSpend
from app.services.tax_calculator import calculate

router = APIRouter(dependencies=[Depends(check_token)])
log = logging.getLogger("calc")


@router.post("/calculate", response_model=CalcResponse, response_model_by_alias=True)
def calculate_api(req: CalcRequest, criteria: Annotated[CriteriaSource, Depends(get_criteria)]) -> CalcResponse:
    started = time.perf_counter()
    data = CalcInput(
        tax_year=req.tax_year, total_salary=req.total_salary, withheld_tax=req.withheld_tax,
        national_pension=req.national_pension, health_insurance=req.health_insurance,
        dependents=req.dependents, children=req.children, monthly_rent=req.monthly_rent,
        housing_saving=req.housing_saving, pension_saving=req.pension_saving, irp_saving=req.irp_saving,
        sme_reduction_yn=req.sme_reduction_yn, homeless_head_yn=req.homeless_head_yn,
        card_spends=[CardSpend(s.category_id, s.pay_method, s.amount) for s in req.card_spends],
    )
    result = calculate(criteria, data)
    log.info("계산 완료 year=%s details=%s %.0fms", req.tax_year, len(result.details),
             (time.perf_counter() - started) * 1000)
    return CalcResponse(
        tax_year=result.tax_year, total_salary=result.total_salary, withheld_tax=result.withheld_tax,
        taxable_income=result.taxable_income, calculated_tax=result.calculated_tax,
        decided_tax=result.decided_tax, expected_refund=result.expected_refund,
        details=[DetailResponse(**vars(d)) for d in result.details],
    )
