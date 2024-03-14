import json
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from aws_lambda_powertools.utilities.data_classes import event_source
from aws_lambda_powertools.utilities.data_classes.sqs_event import SQSEvent, SQSRecord
from common.aws import create_client
from common.dataclasses import load_environment
from common.logger import create_logger, logging_function, logging_handler
from mypy_boto3_events import EventBridgeClient
from mypy_boto3_s3 import S3Client

logger = create_logger(__name__)
jst = timezone(offset=timedelta(hours=+9), name="JST")


@dataclass(frozen=True)
class EnvironmentVariables:
    s3_bucket: str
    s3_prefix: str
    cloudfront_domain: str
    system_name: str
    event_bus_name: str


@dataclass(frozen=True)
class RecordInfo:
    source_arn: str
    message_id: str
    body: str
    unixtime: int
    is_json: bool


@logging_handler(logger)
@event_source(data_class=SQSEvent)
def handler(
    event: SQSEvent,
    context,
    client_s3: S3Client = create_client("s3"),
    client_events: EventBridgeClient = create_client("events"),
):
    env = load_environment(class_dataclass=EnvironmentVariables)
    record = parse_event(event=event)
    key = put_object(
        record=record, bucket=env.s3_bucket, prefix=env.s3_prefix, client=client_s3
    )
    slack_payload = create_slack_payload(
        system_name=env.system_name,
        unixtime_ms=record.unixtime,
        s3_key=key,
        cloudfront_domain=env.cloudfront_domain,
    )
    put_event(
        message=slack_payload, event_bus_name=env.event_bus_name, client=client_events
    )


@logging_function(logger)
def parse_event(*, event: SQSEvent) -> RecordInfo:
    def load_record() -> SQSRecord:
        for x in event.records:
            return x
        raise Exception("unreached: parse_event() -> ")

    record = load_record()
    try:
        json.loads(record.body)
        is_json = True
    except Exception:
        is_json = False
    return RecordInfo(
        source_arn=record.event_source_arn,
        message_id=record.message_id,
        unixtime=int(record.attributes.approximate_first_receive_timestamp),
        body=record.body,
        is_json=is_json,
    )


@logging_function(logger)
def put_object(
    *, record: RecordInfo, bucket: str, prefix: str, client: S3Client
) -> str:
    extname = ".json" if record.is_json else ".txt"
    content_type = "Application/json" if record.is_json else "text/plain"
    key = f"{prefix}/{record.message_id}{extname}"
    client.put_object(
        Bucket=bucket, Key=key, Body=record.body.encode(), ContentType=content_type
    )
    return key


@logging_function(logger)
def create_slack_payload(
    *, system_name: str, unixtime_ms: int, s3_key: str, cloudfront_domain: str
) -> str:
    dt = datetime.fromtimestamp(unixtime_ms / 1000, jst)
    blocks = [
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"<!channel> `{datetime.now(tz=jst)}`"},
        },
        {"type": "divider"},
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*System Name:* `{system_name}`"},
        },
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": "*Type:* `SQS Dead Letter Queue`"},
        },
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*Timestamp:* `{unixtime_ms}`"},
        },
        {"type": "section", "text": {"type": "mrkdwn", "text": f"*Datetime:* `{dt}`"}},
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"*SQS Body Data (CloudFront):* <https://{cloudfront_domain}/{s3_key}|link>",
            },
        },
    ]
    return json.dumps({"blocks": blocks})


@logging_function(logger)
def put_event(*, message: str, event_bus_name: str, client: EventBridgeClient):
    flag = True

    while flag:
        resp = client.put_events(
            Entries=[
                {
                    "Source": "a",
                    "DetailType": "a",
                    "Detail": message,
                    "EventBusName": event_bus_name,
                }
            ]
        )
        flag = resp.get("FailedEntryCount", 0) == 1
