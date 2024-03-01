import os
from dataclasses import fields
from typing import Type, TypeVar

from common.logger import create_logger, logging_function

logger = create_logger(__name__)
T = TypeVar("T")


@logging_function(logger)
def load_environment(*, class_dataclass: Type[T]) -> T:
    return class_dataclass(
        **{k.name: os.environ[k.name.upper()] for k in fields(class_dataclass)}
    )
