from datetime import datetime
from http.client import HTTPResponse
from time import sleep
from typing import Callable
from urllib.request import Request, urlopen

from common.logger import create_logger, logging_function

logger = create_logger(__name__)


def create_http_get_client(*, interval_sec: int) -> Callable[[str], HTTPResponse]:
    dt_prev = datetime.now()

    @logging_function(logger)
    def process(url: str) -> HTTPResponse:
        nonlocal dt_prev
        dt_now = datetime.now()
        delta = dt_now - dt_prev
        wait = interval_sec - delta.total_seconds()
        if wait > 0:
            sleep(wait)
        req = Request(
            url=url, headers={"User-Agent": "luciferous-animanch-bbs-database"}
        )
        try:
            return urlopen(req)
        finally:
            dt_prev = datetime.now()

    return process
