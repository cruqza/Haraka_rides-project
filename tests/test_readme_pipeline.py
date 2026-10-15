"""Tests for the README's pipeline surface (what a recruiter sees on GitHub).

Seam: the rendered README. The pipeline diagram must be a valid mermaid block
and the staging CSVs the diagram and data section promise must exist in the repo.
"""

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
README = REPO / "README.md"
STAGING_CSVS = ("trips_staging.csv", "fleet_staging.csv")


def test_pipeline_diagram_is_valid_mermaid_block():
    text = README.read_text(encoding="utf-8")
    assert "```mermaird" not in text, "misspelled mermaid fence is still present"
    fences = re.findall(r"```mermaid\n(.*?)```", text, flags=re.DOTALL)
    assert len(fences) == 1, "README must contain exactly one mermaid diagram"

    diagram = fences[0]
    assert diagram.lstrip().startswith("flowchart"), "diagram must declare a flowchart type"
    for name in ("trips_staging.csv", "trips_facts.sql", "fleet_staging.csv", "fleet_clean.sql"):
        assert name in diagram, f"diagram lost the {name} node"
    assert "Dashboard" in diagram, "diagram must end at the dashboard"


def test_staging_csvs_referenced_by_pipeline_exist():
    for csv_name in STAGING_CSVS:
        path = REPO / csv_name
        assert path.is_file(), f"{csv_name} is referenced by the README but missing from the repo"


def test_staging_csvs_match_documented_shape():
    import csv

    expected = {"trips_staging.csv": 406, "fleet_staging.csv": 106}
    for csv_name, rows in expected.items():
        with (REPO / csv_name).open(encoding="utf-8", newline="") as fh:
            data_rows = sum(1 for _ in csv.reader(fh)) - 1  # minus header
        assert data_rows == rows, f"{csv_name} should hold {rows} data rows, found {data_rows}"
