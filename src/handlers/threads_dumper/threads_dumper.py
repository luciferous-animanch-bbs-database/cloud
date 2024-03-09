import json
from dataclasses import dataclass
from hashlib import sha256

from botocore.exceptions import ClientError
from common.aws import create_client
from common.dataclasses import load_environment
from common.logger import create_logger, logging_function, logging_handler
from common.repositories.threads import ModelItemThread, RepositoryThreads
from mypy_boto3_dynamodb import DynamoDBClient
from mypy_boto3_s3 import S3Client
from zstd import compress

logger = create_logger(__name__)


@dataclass
class EnvironmentVariables:
    ddb_table_name: str
    s3_bucket: str
    s3_key: str


@logging_handler(logger)
def handler(
    _event,
    _context,
    client_ddb: DynamoDBClient = create_client("dynamodb"),
    client_s3: S3Client = create_client("s3"),
):
    env = load_environment(class_dataclass=EnvironmentVariables)
    items = RepositoryThreads.scan(table_name=env.ddb_table_name, client=client_ddb)
    body = create_body(items=items)
    check_sum_local = calculate_check_sum_sha256(binary=body)
    check_sum_remote = get_check_sum_256(
        bucket=env.s3_bucket, key=env.s3_key, client=client_s3
    )
    logger.info(
        "check sums",
        data={"local": check_sum_local, "remote": check_sum_remote, "size": len(body)},
    )
    if check_sum_local == check_sum_remote:
        return
    put_object(bucket=env.s3_bucket, key=env.s3_key, body=body, client=client_s3)


@logging_function(logger)
def create_body(*, items: list[ModelItemThread]) -> bytes:
    text = json.dumps([x.to_dict() for x in items])
    binary = text.encode()
    return compress(binary, 9)


@logging_function(logger)
def calculate_check_sum_sha256(*, binary: bytes) -> str:
    return sha256(binary).hexdigest()


@logging_function(logger)
def get_check_sum_256(*, bucket: str, key: str, client: S3Client) -> str:
    try:
        resp = client.head_object(Bucket=bucket, Key=key)
        return resp.get("ChecksumSHA256", "")
    except ClientError as e:
        if e.response["Error"]["Code"] == "404":
            return ""
        else:
            raise


@logging_function(logger)
def put_object(*, bucket: str, key: str, body: bytes, check_sum: str, client: S3Client):
    client.put_object(
        Bucket=bucket,
        Key=key,
        Body=body,
        ChecksumSHA256=check_sum,
        ContentType="application/zstd",
    )
