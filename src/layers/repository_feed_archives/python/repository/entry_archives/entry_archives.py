import json
from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Optional

from boto3.dynamodb.conditions import Attr
from boto3.dynamodb.types import Binary
from common.logger import create_logger, logging_function
from common.models.feed import Entry
from mypy_boto3_dynamodb import DynamoDBClient
from mypy_boto3_dynamodb.service_resource import Table
from zstd import compress, decompress

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
            text = json.dumps(entry, ensure_ascii=False)
            binary = compress(text.encode(), 9)
            table.put_item(
                Item=asdict(
                    ModelItemEntryArchive(url=entry["link"], compressed_entry=binary)
                ),
                ConditionExpression=Attr("url").not_exists(),
            )
        except client.exceptions.ConditionalCheckFailedException:
            pass
        except Exception:
            logger.warning("failed to put item", data={"entry": entry}, exc_info=True)
            raise

    @staticmethod
    @logging_function(logger, write=True)
    def get_entry(*, url: str, table: Table) -> Optional[Entry]:
        resp = table.get_item(
            Key={"url": url},
            ProjectionExpression="#compressed_entry",
            ExpressionAttributeNames={"#compressed_entry": "compressed_entry"},
        )
        if "Item" not in resp:
            return None
        binary: Binary = resp["Item"]["compressed_entry"]
        raw = decompress(binary.value)
        return json.loads(raw)
