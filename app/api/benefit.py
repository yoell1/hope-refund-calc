"""POST /benefit · 청년 혜택 자격 진단."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import check_token, get_criteria
from app.repositories.criteria import CriteriaSource
from app.schemas.benefit import BenefitRequest, BenefitResponse, BenefitResultResponse
from app.services.benefit import BenefitInput, diagnose

router = APIRouter(dependencies=[Depends(check_token)])


@router.post("/benefit", response_model=BenefitResponse, response_model_by_alias=True)
def benefit_api(req: BenefitRequest, criteria: Annotated[CriteriaSource, Depends(get_criteria)]) -> BenefitResponse:
    data = BenefitInput(
        tax_year=req.tax_year, total_salary=req.total_salary, birth_date=req.birth_date,
        military_months=req.military_months, hire_date=req.hire_date, company_size=req.company_size,
        homeless_head_yn=req.homeless_head_yn,
    )
    results = diagnose(criteria, data)
    return BenefitResponse(tax_year=req.tax_year, results=[BenefitResultResponse(**vars(r)) for r in results])
