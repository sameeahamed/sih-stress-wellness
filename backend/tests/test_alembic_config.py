"""Verify Alembic configuration is valid and migration structure is sound."""

import os

from alembic.config import Config
from alembic.script import ScriptDirectory

ALEMBIC_INI = os.path.join(os.path.dirname(__file__), "..", "alembic.ini")
EXPECTED_REVISION = "c51826e301a9"


def test_alembic_ini_exists() -> None:
    assert os.path.isfile(ALEMBIC_INI), f"Missing {ALEMBIC_INI}"


def test_alembic_config_loadable() -> None:
    alembic_cfg = Config(ALEMBIC_INI)
    assert alembic_cfg.get_main_option("script_location") == "alembic"


def test_initial_revision_present() -> None:
    alembic_cfg = Config(ALEMBIC_INI)
    script = ScriptDirectory.from_config(alembic_cfg)
    heads = script.get_heads()
    assert len(heads) == 1, f"Expected exactly 1 head, got: {heads}"
    assert EXPECTED_REVISION in heads


def test_no_multiple_heads() -> None:
    alembic_cfg = Config(ALEMBIC_INI)
    script = ScriptDirectory.from_config(alembic_cfg)
    heads = script.get_heads()
    # Exactly one head means migrations are in a clean linear chain.
    assert len(heads) == 1