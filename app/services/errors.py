"""계산 중 화면에 알려야 하는 오류."""


class NoCriteriaError(Exception):
    """해당 연도 기준값이 없음 → 응답 {"error": "NO_CRITERIA", "message": "해당 연도 기준값이 없어요"}"""

    def __init__(self, message: str = "해당 연도 기준값이 없어요"):
        super().__init__(message)
        self.message = message
