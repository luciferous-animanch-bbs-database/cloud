from typing import TypedDict


class Tag(TypedDict):
    term: str


class Entry(TypedDict):
    title: str
    link: str
    summary: str
    published_parsed: list[int]
    tags: list[Tag]


class Feed(TypedDict):
    entries: list[Entry]
