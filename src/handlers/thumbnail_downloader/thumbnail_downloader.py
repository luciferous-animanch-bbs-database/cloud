from dataclasses import dataclass
from hashlib import sha224
from io import BytesIO

import pillow_avif
from aws_lambda_powertools.utilities.data_classes import event_source
from aws_lambda_powertools.utilities.data_classes.sqs_event import SQSEvent, SQSRecord
from common.aws import create_client, create_resource
from common.dataclasses import load_environment
from common.http import sec3_http_get_client
from common.logger import create_logger, logging_function, logging_handler
from common.repositories.threads.threads import KeysThread, RepositoryThreads
from mypy_boto3_dynamodb import DynamoDBServiceResource
from mypy_boto3_s3 import S3Client
from PIL import Image

logger = create_logger(__name__)


@dataclass(frozen=True)
class EnvironmentVariables:
    dynamodb_table_name: str
    s3_bucket: str
    s3_prefix: str


@logging_handler(logger)
@event_source(data_class=SQSEvent)
def handler(
    event: SQSEvent,
    context,
    resource_ddb: DynamoDBServiceResource = create_resource("dynamodb"),
    client_s3: S3Client = create_client("s3"),
):
    env = load_environment(class_dataclass=EnvironmentVariables)
    table = resource_ddb.Table(env.dynamodb_table_name)
    key_item = get_key(event=event)
    thumbnail = RepositoryThreads.get_thumbnail_url(key=key_item, table=table)
    key_s3 = create_s3_key(s3_prefix=env.s3_prefix, url=thumbnail)
    http_response = sec3_http_get_client(thumbnail)
    binary_raw = http_response.read()
    binary_avif = convert_to_avif(binary=binary_raw)
    put_object(bucket=env.s3_bucket, key=key_s3, body=binary_avif, client=client_s3)


@logging_function(logger)
def get_key(*, event: SQSEvent) -> KeysThread:
    def load_event() -> SQSRecord:
        for x in event.records:
            return x
        raise ValueError("unreached: get_key() -> load_event()")

    record = load_event()
    data = record.json_body
    return KeysThread(
        category=data["dynamodb"]["Keys"]["category"]["S"],
        sort_key=data["dynamodb"]["Keys"]["sort_key"]["S"],
    )


@logging_function(logger)
def create_s3_key(*, s3_prefix: str, url: str) -> str:
    digest = sha224(url.encode()).hexdigest()
    return f"{s3_prefix}/{digest}.avif"


@logging_function(logger)
def convert_to_avif(*, binary: bytes) -> bytes:
    with BytesIO(binary) as f:
        img = Image.open(f).copy()

    with BytesIO() as f:
        img.save(f, format="avif", quality=75, speed=1)
        return f.getvalue()


@logging_function(logger)
def put_object(*, bucket: str, key: str, body: bytes, client: S3Client):
    client.put_object(Bucket=bucket, Key=key, Body=body, ContentType="image/avif")
