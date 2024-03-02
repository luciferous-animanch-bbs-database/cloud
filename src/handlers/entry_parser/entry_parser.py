from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from aws_lambda_powertools.utilities.data_classes import event_source
from aws_lambda_powertools.utilities.data_classes.sqs_event import SQSEvent, SQSRecord
from common.aws import create_resource
from common.dataclasses import load_environment
from common.logger import create_logger, logging_function, logging_handler
from common.models.feed import Entry
from mypy_boto3_dynamodb import DynamoDBServiceResource
from repository.entry_archives import RepositoryEntryArchives
from repository.threads import ModelItemThread, RepositoryThreads

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


@dataclass(frozen=True)
class EnvironmentVariables:
    ddb_table_name_entry_archives: str
    ddb_table_name_threads: str


@logging_handler(logger)
@event_source(data_class=SQSEvent)
def handler(
    event: SQSEvent,
    context,
    resource_ddb: DynamoDBServiceResource = create_resource("dynamodb"),
):
    env = load_environment(class_dataclass=EnvironmentVariables)
    table_entry_archives = resource_ddb.Table(env.ddb_table_name_entry_archives)
    table_threads = resource_ddb.Table(env.ddb_table_name_threads)
    url = get_url(event=event)
    entry = RepositoryEntryArchives.get_entry(url=url, table=table_entry_archives)
    item = convert(entry=entry)
    RepositoryThreads.put_item(item=item, table=table_threads)


@logging_function(logger)
def get_url(*, event: SQSEvent) -> str:
    def load_event() -> SQSRecord:
        for x in event.records:
            return x
        raise ValueError("unreached: parse_event() -> load_event()")

    record = load_event()
    data = record.json_body
    return data["dynamodb"]["Keys"]["url"]["S"]


@logging_function(logger)
def convert(*, entry: Entry) -> ModelItemThread:
    try:
        category = entry["tags"][0]["term"]
    except Exception:
        category = "unknown"

    url = entry["link"]

    dt_utc = datetime(*entry["published_parsed"][:6], tzinfo=timezone.utc)
    unixtime = int(dt_utc.timestamp())
    dt_jst = datetime.fromtimestamp(unixtime, tz=jst)
    datetime_str = dt_jst.strftime("%y/%m/%d(%a) %H:%M:%S")
    for k, v in mapping_week.items():
        datetime_str = datetime_str.replace(k, v)

    return ModelItemThread(
        category=category,
        sort_key=f"{unixtime}={url}",
        url=url,
        title=entry["title"],
        thumbnail=entry["summary"],
        unixtime=unixtime,
        datetime=datetime_str,
    )
