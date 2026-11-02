"""API 모양 공통: JSON 이름은 camelCase (노션 「동석님 전달」 · Spring과 같은 이름)."""

from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, extra="forbid")


class ErrorResponse(CamelModel):
    error: str
    message: str
