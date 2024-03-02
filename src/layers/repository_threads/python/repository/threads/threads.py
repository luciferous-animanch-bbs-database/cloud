from dataclasses import asdict, dataclass

from common.logger import create_logger, logging_function
from mypy_boto3_dynamodb.service_resource import Table


@dataclass
class ModelItemThread:
    category: str
    sort_key: str
    url: str
    title: str
    thumbnail: str
    unixtime: int
    datetime: str


logger = create_logger(__name__)


class RepositoryThreads:
    @staticmethod
    @logging_function(logger)
    def put_item(*, item: ModelItemThread, table: Table):
        table.put_item(Item=asdict(item))
