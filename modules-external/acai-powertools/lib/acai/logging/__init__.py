"""
acai.logging — Hexagonal logging module
========================================

Public surface
--------------
- ``LoggerPort``, ``LogLevel``  — port contract (depend on this)
- ``LoggerConfig``              — shared configuration value object
- ``Logger``, ``LoggerContext``    — domain service (context stack + Lambda decorator)
- ``create_logger()``              — factory that wires adapters for you

Adapters (import directly when needed)
--------------------------------------
- ``acai.logging.adapters.ConsoleLogger``
- ``acai.logging.adapters.AwsLambdaPtLogger``
- ``acai.logging.adapters.CloudWatchLogger``
- ``acai.logging.adapters.FileLogger``
"""

from __future__ import annotations

from acai.logging.domain import Logger, LoggerConfig, LoggerContext
from acai.logging.log_level import LogLevel
from acai.logging.ports import Loggable, LoggerPort


def create_lambda_logger(
    config: LoggerConfig | None = None,
) -> Logger:
    """Factory that builds a ready-to-use ``Logger``.

    Parameters
    ----------
    config:
        Optional configuration.  Defaults are sensible for local development.
    """
    if config is None:
        config = LoggerConfig()

    from acai.logging.adapters.outbound.aws_lambda_pt_logger import AwsLambdaPtLogger

    adapter = AwsLambdaPtLogger(
        service=config.service_name,
        level=config.log_level,
        use_powertools=config.log_format != "FLAT",
    )

    logger = Logger(adapter)
    logger.disable_noisy_logging()
    return logger


__all__ = [
    "LoggerPort",
    "Loggable",
    "LogLevel",
    "LoggerConfig",
    "Logger",
    "LoggerContext",
    "create_logger",
    "create_lambda_logger",
]
