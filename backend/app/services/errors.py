"""Service-level errors; routers translate these into HTTP responses."""


class NotFoundError(Exception):
    pass


class ConflictError(Exception):
    pass
