from base64 import b64encode
from dataclasses import asdict, is_dataclass
from decimal import Decimal
from logging import DEBUG
from typing import Type

from aws_lambda_powertools import Logger
from boto3.dynamodb.conditions import AttributeBase, ConditionBase
from zstd import compress


def custom_default(obj):
    if isinstance(obj, Decimal):
        return num if (num := int(obj)) == obj else float(str(obj))
    if is_dataclass(obj):
        return str(obj) if isinstance(obj, Type) else asdict(obj)
    if isinstance(obj, set):
        return list(obj)
    if isinstance(obj, AttributeBase):
        return obj.name
    if isinstance(obj, ConditionBase):
        return obj.get_expression()
    if isinstance(obj, bytes):
        return {
            "type": "byts",
            "detail": "compress by zstd and base64 encode",
            "value": b64encode(compress(obj, 9)).decode(),
        }
    try:
        return {"type": str(type(obj)), "value": str(obj)}
    except Exception as e:
        return {"type": str(type(obj)), "err": {"type": str(type(e)), "msg": str(e)}}


def create_logger(name: str) -> Logger:
    return Logger(
        service=name, level=DEBUG, use_rfc3339=True, json_default=custom_default
    )
