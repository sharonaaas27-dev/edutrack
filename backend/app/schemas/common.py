"""Shared paginated envelope used by list endpoints."""
from pydantic import BaseModel


class Page(BaseModel):
    total: int
    page: int
    page_size: int


def paginate(items: list, total: int, page: int, page_size: int) -> dict:
    return {"items": items, "total": total, "page": page, "page_size": page_size}
