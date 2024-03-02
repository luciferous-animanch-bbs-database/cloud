import json
from base64 import b64encode
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from zlib import compress

import feedparser
from boto3.dynamodb.conditions import Attr
from common.aws import create_client, create_resource
from common.dataclasses import load_environment
from common.logger import create_logger, logging_function, logging_handler
from common.models.feed import Entry
from mypy_boto3_dynamodb import DynamoDBClient, DynamoDBServiceResource


@dataclass
class Item:
    title: str
    url: str
    thumbnail: str
    unixtime: int
    timestamp: str
    category: str
    sort_key: str
    encoded_compressed_raw: str


@dataclass
class EnvironmentVariables:
    dynamodb_table_name: str


logger = create_logger(__name__)
jst = timezone(offset=timedelta(hours=+9), name="JST")
mapping_week = {
    "Sun": "日",
    "Mon": "月",
    "Tue": "火",
    "Wed": "水",
    "Thu": "木",
    "Fri": "金",
    "Sat": "土",
}


@logging_handler(logger)
def handler(
    event,
    context,
    resource_ddb: DynamoDBServiceResource = create_resource("dynamodb"),
    client_ddb: DynamoDBClient = create_client("dynamodb"),
):
    env = load_environment(class_dataclass=EnvironmentVariables)
    entries = get_entries()
    items = [convert(entry=x) for x in entries]
    put_items(
        items=items,
        table_name=env.dynamodb_table_name,
        client=client_ddb,
        resource=resource_ddb,
    )


@logging_function(logger)
def get_entries() -> list[Entry]:
    resp = feedparser.parse("https://bbs.animanch.com/index.xml")
    return resp["entries"]


@logging_function(logger)
def convert(*, entry: Entry) -> Item:
    category = "unknown"
    try:
        category = entry["tags"][0]["term"]
    except Exception:
        pass
    unixtime = int(
        datetime(*entry["published_parsed"][:6], tzinfo=timezone.utc).timestamp()
    )
    url = entry["link"]
    dt_jst = datetime.fromtimestamp(unixtime, tz=jst)
    timestamp = dt_jst.strftime("%y/%m/%d(%a) %H:%M:%S")
    for k, v in mapping_week.items():
        timestamp = timestamp.replace(k, v)

    return Item(
        title=entry["title"],
        url=entry["link"],
        thumbnail=entry["summary"],
        unixtime=unixtime,
        timestamp=timestamp,
        category=category,
        sort_key=f"{unixtime}={url}",
        encoded_compressed_raw=b64encode(
            compress(json.dumps(entry, ensure_ascii=False).encode())
        ).decode(),
    )


@logging_function(logger)
def put_items(
    *,
    items: list[Item],
    table_name: str,
    client: DynamoDBClient,
    resource: DynamoDBServiceResource,
):
    table = resource.Table(table_name)
    errors: list[tuple[Exception, Item]] = []
    for item in items:
        try:
            table.put_item(
                Item=asdict(item), ConditionExpression=Attr("sort_key").not_exists()
            )
        except client.exceptions.ConditionalCheckFailedException:
            pass
        except Exception as e:
            errors.append((e, item))

    if len(errors) > 0:
        for e, item in errors:
            logger.warning("failed to put item", data={"error": e, "item": item})
        logger.error("failed to put items")
