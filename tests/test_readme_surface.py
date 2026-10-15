"""Tests for the README's recruiter-facing surface.

Seam: the rendered README on GitHub. It must state the business problem up
front, document the SQL pipeline stages, embed a committed image, and explain
how to reproduce the pipeline.
"""

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
README = REPO / "README.md"


def _readme():
    return README.read_text(encoding="utf-8")


def test_readme_states_business_problem_up_front():
    text = _readme()
    intro = text.split("##", 1)[0].lower()
    assert "revenue" in intro and "route" in intro, (
        "the opening must state the business problem: route revenue/profitability"
    )


def test_readme_documents_pipeline_stages_and_tools():
    text = _readme()
    for stage in ("staging", "cleaning", "bookings"):
        assert stage in text.lower(), f"pipeline stage '{stage}' must be documented"
    for tool in ("PostgreSQL", "Power BI"):
        assert tool in text, f"tool '{tool}' must be mentioned"


def test_readme_embeds_a_committed_image():
    text = _readme()
    images = re.findall(r"!\[[^\]]*\]\((?!http)([^)]+)\)", text)
    assert images, "README must embed at least one local (committed) image"
    for path in images:
        assert (REPO / path).is_file(), f"embedded image {path} does not exist in the repo"


def test_readme_has_reproduction_steps():
    text = _readme()
    run = text.lower().split("how to run")[-1]
    assert "staging" in run and ("power bi" in run or "dashboard" in run), (
        "run steps must cover loading staging data through the dashboard"
    )
