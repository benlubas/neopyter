#!/usr/bin/env python3
import websocket
import argparse
from enum import Enum


class WorkMode(Enum):
    echo = "echo"

    def __str__(self) -> str:
        return self.value


parser = argparse.ArgumentParser()

parser.add_argument(
    "--address",
    type=str,
    required=False,
    default="ws://127.0.0.1:9003/",
    help="websocket address",
)
parser.add_argument(
    "--mode",
    type=WorkMode,
    required=False,
    default=WorkMode.echo,
    choices=list(WorkMode),
    help="wrok mode",
)
parser.add_argument("content", type=str, help="content to send")

opts = parser.parse_args()


def echo():
    client = websocket.create_connection(opts.address)
    client.send(opts.content)
    result = client.recv()
    print(result)
    client.close()
    print("exit")


if opts.mode == WorkMode.echo:
    echo()
