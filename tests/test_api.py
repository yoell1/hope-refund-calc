import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_criteria
from app.main import app
from tests.criteria_data import criteria


@pytest.fixture
def client(monkeypatch):
    monkeypatch.delenv("CALC_API_TOKEN", raising=False)
    app.dependency_overrides[get_criteria] = criteria
    yield TestClient(app)
    app.dependency_overrides.clear()


BODY = {"taxYear": 2026, "totalSalary": 30_000_000, "withheldTax": 600_000, "nationalPension": 2_700_000,
        "cardSpends": [{"categoryId": 1, "payMethod": "CREDIT", "amount": 12_000_000}]}


def test_계산_응답_이름은_동석님_전달_그대로(client):
    body = client.post("/calculate", json=BODY).json()
    assert set(body) == {"taxYear", "totalSalary", "withheldTax", "taxableIncome", "calculatedTax", "decidedTax",
                         "expectedRefund", "details"}
    assert set(body["details"][0]) == {"typeCode", "typeName", "kind", "baseAmount", "deductionAmount", "sourceNote"}


def test_음수_입력은_막는다(client):
    response = client.post("/calculate", json={**BODY, "totalSalary": -1})
    assert response.status_code == 400
    assert response.json()["error"] == "VALIDATION"


def test_모르는_칸은_막는다(client):
    response = client.post("/calculate", json={**BODY, "memberId": 2})
    assert response.status_code == 400


def test_기준값_없는_연도(client):
    response = client.post("/calculate", json={**BODY, "taxYear": 2024})
    assert response.json() == {"error": "NO_CRITERIA", "message": "해당 연도 기준값이 없어요"}


def test_토큰이_설정되면_없는_요청은_막는다(client, monkeypatch):
    monkeypatch.setenv("CALC_API_TOKEN", "secret")
    assert client.post("/calculate", json=BODY).status_code == 401
    assert client.post("/calculate", json=BODY, headers={"X-Calc-Token": "secret"}).status_code == 200


def test_혜택_진단(client):
    body = client.post("/benefit", json={"taxYear": 2026, "totalSalary": 30_000_000, "birthDate": "1995-05-10",
                                         "hireDate": "2023-03-01", "companySize": "SME", "homelessHeadYn": "Y"}).json()
    assert [r["benefitCode"] for r in body["results"]] == ["SME_YOUTH", "RENT", "HOUSING_SAVING"]


def test_없는_주소는_짧은_안내만(client):
    response = client.get("/admin")
    assert response.status_code == 404
    assert set(response.json()) == {"error", "message"}
