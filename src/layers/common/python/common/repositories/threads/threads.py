from dataclasses import asdict, dataclass, field
from decimal import Decimal
from typing import Optional

from boto3.dynamodb.types import TypeDeserializer
from common.logger import create_logger, logging_function
from mypy_boto3_dynamodb import DynamoDBClient
from mypy_boto3_dynamodb.service_resource import Table

ddb_value_deserializer = TypeDeserializer()


@dataclass
class ModelItemThread:
    category: str
    sort_key: str
    url: str
    title: str
    thumbnail: str
    unixtime: int | Decimal
    datetime: str
    updated_at: Optional[str] = field(default=None)

    def to_dict(self) -> dict:
        return {
            "category": self.category,
            "sort_key": self.sort_key,
            "url": self.url,
            "title": self.title,
            "thumbnail": self.thumbnail,
            "unixtime": int(self.unixtime),
            "datetime": self.datetime,
            "updated_at": self.updated_at,
        }


@dataclass
class KeysThread:
    category: str
    sort_key: str


class ItemNotFoundError(Exception):
    pass


logger = create_logger(__name__)


class RepositoryThreads:
    @staticmethod
    @logging_function(logger)
    def put_item(*, item: ModelItemThread, table: Table):
        table.put_item(Item=asdict(item))

    @staticmethod
    @logging_function(logger)
    def get_thumbnail_url(*, key: KeysThread, table: Table) -> str:
        resp = table.get_item(
            Key=asdict(key),
            ProjectionExpression="#thumbnail",
            ExpressionAttributeNames={"#thumbnail": "thumbnail"},
        )

        item = resp.get("Item")
        if item is None:
            raise ItemNotFoundError
        return item["thumbnail"]

    @staticmethod
    @logging_function(logger)
    def scan(*, table_name: str, client: DynamoDBClient) -> list[ModelItemThread]:
        result = []

        for resp in client.get_paginator("scan").paginate(TableName=table_name):
            result += [
                ModelItemThread(
                    **{k: ddb_value_deserializer.deserialize(v) for k, v in x.items()}
                )
                for x in resp["Items"]
            ]

        return result
