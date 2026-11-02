from app.repositories.oracle_criteria import OracleCriteria


class FakeClock:
    def __init__(self):
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


def _criteria(clock: FakeClock) -> tuple[OracleCriteria, list[int]]:
    calls: list[int] = []
    source = OracleCriteria(cache_seconds=300, clock=clock)

    def fake_query(sql: str, **params) -> list[tuple]:
        calls.append(1)
        return [(0, None, 6, 0)]

    source._query = fake_query
    return source, calls


def test_캐시_시간_안에는_DB를_다시_읽지_않는다():
    clock = FakeClock()
    source, calls = _criteria(clock)
    source.brackets(2026, "TAX_RATE")
    clock.now = 299
    source.brackets(2026, "TAX_RATE")
    assert len(calls) == 1


def test_캐시_시간이_지나면_DB에서_다시_읽는다():
    clock = FakeClock()
    source, calls = _criteria(clock)
    source.brackets(2026, "TAX_RATE")
    clock.now = 300
    source.brackets(2026, "TAX_RATE")
    assert len(calls) == 2


def test_연도와_구간_종류는_따로_캐시한다():
    clock = FakeClock()
    source, calls = _criteria(clock)
    source.brackets(2026, "TAX_RATE")
    source.brackets(2025, "TAX_RATE")
    source.brackets(2026, "EARNED_CREDIT")
    assert len(calls) == 3
