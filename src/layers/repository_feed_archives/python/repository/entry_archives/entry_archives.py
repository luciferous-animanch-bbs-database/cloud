import json
from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Optional

from boto3.dynamodb.conditions import Attr
from common.logger import create_logger, logging_function
from common.models.feed import Entry
from mypy_boto3_dynamodb import DynamoDBClient
from mypy_boto3_dynamodb.service_resource import Table
from zstd import compress

jst = timezone(offset=timedelta(hours=+9), name="JST")


@dataclass
class ModelItemEntryArchive:
    url: str
    compressed_entry: bytes
    disabled: bool = field(default=False)
    created_at: str = field(default_factory=lambda: str(datetime.now(tz=jst)))


logger = create_logger(__name__)


class RepositoryEntryArchives:
    @staticmethod
    @logging_function(logger)
    def put_entry(*, entry: Entry, client: DynamoDBClient, table: Table):
        try:
            table.put_item(
                Item=asdict(
                    ModelItemEntryArchive(
                        url=entry["link"],
                        compressed_entry=compress(
                            json.dumps(entry, ensure_ascii=False), 9
                        ),
                    )
                ),
                ConditionExpression=Attr("url").not_exists(),
            )
        except client.exceptions.ConditionalCheckFailedException:
            pass

    @staticmethod
    @logging_function(logger)
    def get_entry(*, url: str, table: Table) -> Optional[ModelItemEntryArchive]:
        resp = table.get_item(Key={"url": url})
        if "Item" in resp:
            return None
        else:
            return ModelItemEntryArchive(**resp["Item"])