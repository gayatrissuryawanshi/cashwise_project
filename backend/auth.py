from datetime import datetime, timedelta, timezone

import bcrypt
from jose import jwt, JWTError


SECRET_KEY = "cashflow-engine-secret-key"

ALGORITHM = "HS256"


# ==========================================
# PASSWORD HASHING
# ==========================================

def hash_password(password: str) -> str:

    password_bytes = password.encode("utf-8")

    hashed = bcrypt.hashpw(
        password_bytes,
        bcrypt.gensalt()
    )

    return hashed.decode("utf-8")


# ==========================================
# PASSWORD VERIFICATION
# ==========================================

def verify_password(
    password: str,
    password_hash: str
) -> bool:

    return bcrypt.checkpw(
        password.encode("utf-8"),
        password_hash.encode("utf-8")
    )


# ==========================================
# CREATE JWT
# ==========================================

def create_access_token(user_id: int):

    expire = (
        datetime.now(timezone.utc)
        + timedelta(hours=24)
    )

    payload = {
        "user_id": user_id,
        "exp": expire
    }

    return jwt.encode(
        payload,
        SECRET_KEY,
        algorithm=ALGORITHM
    )


# ==========================================
# DECODE JWT
# ==========================================

def decode_access_token(token: str):

    try:

        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )

        user_id = payload.get("user_id")

        if user_id is None:
            return None

        return int(user_id)

    except (
        JWTError,
        ValueError,
        TypeError
    ):
        return None