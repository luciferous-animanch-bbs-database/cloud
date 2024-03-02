from dataclasses import dataclass

import feedparser
from common.aws import create_client, create_resource
from common.dataclasses import load_environment
from common.logger import create_logger, logging_function, logging_handler
from common.models.feed import Entry, Feed
from mypy_boto3_dynamodb import DynamoDBClient
from mypy_boto3_dynamodb.service_resource import DynamoDBServiceResource, Table
from repository.entry_archives import RepositoryEntryArchives


@dataclass
class EnvironmentVariables:
    dynamodb_table_name: str


logger = create_logger(__name__)


@logging_handler(logger)
def handler(
    _event,
    _context,
    client_ddb: DynamoDBClient = create_client("dynamodb"),
    resource_ddb: DynamoDBServiceResource = create_resource("dynamodb"),
):
    env = load_environment(class_dataclass=EnvironmentVariables)
    table = resource_ddb.Table(env.dynamodb_table_name)
    entries = get_entries()
    put_entries(all_entries=entries, client=client_ddb, table=table)


@logging_function(logger)
def get_entries() -> list[Entry]:
    resp: Feed = feedparser.parse("https://bbs.animanch.com/index.xml")
    return resp["entries"]


@logging_function(logger)
def put_entries(*, all_entries: list[Entry], client: DynamoDBClient, table: Table):
    errors: list[tuple[Exception, Entry]] = []
    for entry in all_entries:
        try:
            RepositoryEntryArchives.put_entry(entry=entry, client=client, table=table)
        except Exception as e:
            errors.append((e, entry))

    if len(errors) > 0:
        for e, entry in errors:
            logger.warning("item of failed to put", data={"error": e, "entry": entry})
        logger.error("failed to put items (詳細はログを見て)")
