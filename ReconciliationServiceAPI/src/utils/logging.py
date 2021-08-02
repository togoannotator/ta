import os

from loguru import logger
import sys


class ServerLogger:
    def __init__(self, log_level: str):
        self.logger = logger
        self.logger.remove()
        path = 'log'
        log_name = 'application.log'
        if not os.path.exists(path):
            os.mkdir(path)
        self.logger.add(os.path.join(path, log_name), colorize=False,
                        level=log_level)
        self.logger.add(sys.stdout, colorize=False, level=log_level)
