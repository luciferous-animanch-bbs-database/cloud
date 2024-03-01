import json
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from os.path import basename
from typing import Optional
from urllib.parse import quote_plus

from aws_lambda_powertools.logging.types import (
    PowertoolsLogRecord,
    PowertoolsStackTrace,
)
from aws_lambda_powertools.utilities.data_classes import (
    CloudWatchLogsEvent,
    event_source,
)
from aws_lambda_powertools.utilities.data_classes.cloud_watch_logs_event import (
    CloudWatchLogsLogEvent,
)
from common.aws import create_client
from common.dataclasses import load_environment
from common.logger import create_logger, logging_function, logging_handler
from mypy_boto3_events import EventBridgeClient


@dataclass(frozen=True)
class EnvironmentVariables:
    event_bus_name: str
    aws_default_region: str
    system_name: str


@dataclass(frozen=True)
class LogMessage:
    lambda_request_id: Optional[str]
    timestamp: int
    message: str
    error_message: Optional[str] = field(default=None)


JST = timezone(offset=timedelta(hours=+9), name="JST")
logger = create_logger(__name__)


@event_source(data_class=CloudWatchLogsEvent)
@logging_handler(logger)
def handler(
    event: CloudWatchLogsEvent,
    context,
    client_events: EventBridgeClient = create_client("events"),
):
    env = load_environment(class_dataclass=EnvironmentVariables)
    decompressed_log = event.parse_logs_data()
    messages = [
        create_slack_payload(
            log_group=decompressed_log.log_group,
            log_stream=decompressed_log.log_stream,
            region=env.aws_default_region,
            system_name=env.system_name,
            log_event=log_event,
        )
        for log_event in decompressed_log.log_events
    ]
    for i, m in enumerate(messages):
        logger.debug("log event", data={"index": i, "message": m})
    put_events(
        messages=messages, event_bus_name=env.event_bus_name, client=client_events
    )


@logging_function(logger)
def create_url_cw_logs(
    *,
    name_log_group: str,
    name_log_stream: str,
    region: str,
    timestamp: int,
    lambda_request_id: Optional[str],
) -> str:
    part = [
        "https://",
        region,
        ".console.aws.amazon.com/cloudwatch/home?region=",
        region,
        "#logsV2:log-groups/log-group/",
        quote_plus(quote_plus(name_log_group)).replace("%", "$"),
        "/log-events/",
        quote_plus(quote_plus(name_log_stream)).replace("%", "$"),
        quote_plus("?").replace("%", "$"),
    ]
    if lambda_request_id is None:
        start = timestamp - 900_000  # 1000 ms/s * 60 s/m * 15 m = 900,000 ms
        end = timestamp + 10_000
        part += [
            quote_plus(f"start={start}").replace("%", "$"),
            quote_plus("&").replace("%", "$"),
            quote_plus(f"end={end}").replace("%", "$"),
        ]
    else:
        part += [
            quote_plus("filterPattern=").replace("%", "$"),
            quote_plus(quote_plus(f'"{lambda_request_id}"')).replace("%", "$"),
        ]
    return "".join(part)


@logging_function(logger)
def create_url_lambda(*, function_name: str, region: str) -> str:
    return "".join(
        [
            "https://",
            region,
            ".console.aws.amazon.com/lambda/home?region=",
            region,
            "#/functions/",
            function_name,
        ]
    )


@logging_function(logger, write=True, with_return=True)
def parse_message(*, log_event: CloudWatchLogsLogEvent) -> LogMessage:
    try:
        data: PowertoolsLogRecord = json.loads(log_event.message)
    except Exception:
        return LogMessage(
            lambda_request_id=None,
            timestamp=log_event.timestamp,
            message=log_event.message[:300],
        )
    if "stack_trace" in data:
        stack_trace: PowertoolsStackTrace = data["stack_trace"]
        return LogMessage(
            lambda_request_id=data.get("function_request_id"),
            timestamp=log_event.timestamp,
            message=str(data["message"])[:300],
            error_message="[{0}.{1}] {2}".format(
                stack_trace["module"], stack_trace["type"], stack_trace["value"]
            )[:300],
        )
    return LogMessage(
        lambda_request_id=data.get("function_request_id"),
        timestamp=log_event.timestamp,
        message=str(data["message"])[:300],
    )


@logging_function(logger)
def create_slack_payload(
    *,
    log_group: str,
    log_stream: str,
    region: str,
    system_name: str,
    log_event: CloudWatchLogsLogEvent,
) -> str:
    function_name = basename(log_group)
    log_message = parse_message(log_event=log_event)
    blocks = [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"<!channel> `{datetime.now(tz=JST)}`",
            },
        },
        {"type": "divider"},
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*System Name:* `{0}`".format(system_name),
            },
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Log Group:* `{0}`".format(log_group),
            },
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Log Stream:* `{0}`".format(log_stream),
            },
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Timestamp:* `{0}`".format(log_event.timestamp),
            },
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Datetime:* `{0}`".format(
                    datetime.fromtimestamp(log_event.timestamp / 1000, tz=JST)
                ),
            },
        },
    ]
    if log_message.lambda_request_id is not None:
        blocks.append(
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "*Lambda Request ID:* `{0}`".format(
                        log_message.lambda_request_id
                    ),
                },
            }
        )
    blocks += [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Lambda Console:* <{0}|link>".format(
                    create_url_lambda(function_name=function_name, region=region)
                ),
            },
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*CloudWatch Logs Link:* <{0}|link>".format(
                    create_url_cw_logs(
                        name_log_group=log_group,
                        name_log_stream=log_stream,
                        region=region,
                        timestamp=log_message.timestamp,
                        lambda_request_id=log_message.lambda_request_id,
                    )
                ),
            },
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Message:*",
            },
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "```\n{0}\n```".format(log_message.message),
            },
        },
    ]
    if log_message.error_message is not None:
        blocks += [
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "*Error Message:*",
                },
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "```\n{0}\n```".format(log_message.error_message),
                },
            },
        ]
    return json.dumps({"blocks": blocks})


@logging_function(logger)
def put_events(*, messages: list[str], event_bus_name: str, client: EventBridgeClient):
    mapping_message = {str(i): x for i, x in enumerate(messages)}
    union_succeeded = set()
    union_all = set(mapping_message.keys())

    while union_succeeded != union_all:
        entries = []
        keys = []
        for k, v in mapping_message.items():
            if len(entries) == 10:
                break
            if k in union_succeeded:
                continue
            keys.append(k)
            entries.append(
                {
                    "Source": "a",
                    "DetailType": "a",
                    "Detail": v,
                    "EventBusName": event_bus_name,
                }
            )

        resp = client.put_events(Entries=entries)
        failed_keys = []
        for k, entry in zip(keys, resp["Entries"]):
            if "EventId" in entry:
                union_succeeded.add(k)
            else:
                failed_keys.append(k)
        if len(failed_keys) > 0:
            logger.warning("failed to put events", data={"failed index": failed_keys})
            raise ValueError("has entries failed to put events")
