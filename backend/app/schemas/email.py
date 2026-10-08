"""Email type: strict validation, but local/reserved domains allowed.

Pydantic's EmailStr (email-validator) rejects special-use domains such as
`.local`/`.localhost`, which this project's documented dev accounts use
(e.g. admin@edutrack.local). This type keeps full email-validator strictness
for normal addresses and falls back to a shape + normalization check for
reserved/local domains only. Production deployments should still prefer
routable addresses.
"""
import re
from typing import Annotated

from email_validator import EmailNotValidError, validate_email
from pydantic import BeforeValidator

_LOCAL_SHAPE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _validate(value: object) -> str:
    if not isinstance(value, str):
        raise ValueError("Invalid email address.")
    text = value.strip()
    try:
        return validate_email(text, check_deliverability=False).normalized
    except EmailNotValidError as e:
        reason = str(e)
        if ("special-use" in reason or "reserved name" in reason) and (
            _LOCAL_SHAPE.match(text)
        ):
            return text.lower()
        raise ValueError("Invalid email address.") from e


Email = Annotated[str, BeforeValidator(_validate)]
