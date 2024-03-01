from datetime import datetime, timezone
from functools import wraps
from typing import Callable
from uuid import uuid4

from aws_lambda_powertools import Logger


def logging_function(
    logger: Logger, *, write: bool = False, with_return: bool = False
) -> Callable:
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def process(*args, **kwargs):
            name_function = func.__name__
            id_call = str(uuid4())
            dt_start = datetime.now(tz=timezone.utc)
            result = None
            is_error = False
            try:
                data_start = {"args": args, "kwargs": kwargs}
                if write:
                    logger.debug(
                        f'start function "{name_function}" ({id_call})', data=data_start
                    )
                result = func(*args, **kwargs)
                return result
            except Exception as e:
                logger.debug(
                    f"error occurred: {e}",
                    exc_info=True,
                    data={"args": args, "kwargs": kwargs},
                )
                is_error = True
                raise
            finally:
                dt_end = datetime.now(tz=timezone.utc)
                delta = dt_end - dt_start
                data_end = {
                    "args": args,
                    "kwargs": kwargs,
                    "duration": {
                        "str": str(delta),
                        "total_seconds": delta.total_seconds(),
                    },
                }
                if with_return:
                    data_end["return"] = result
                if write or is_error:
                    status = "failed" if is_error else "succeeded"
                    logger.debug(
                        f'{status} function "{name_function}" ({id_call})',
                        data=data_end,
                    )

        return process

    return decorator
