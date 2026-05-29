---
title: Python Coding Standards
type: instruction
description: "Conventions for Python-centric projects, including data science and ML pipelines with pandas, scikit-learn, DuckDB, and Jupyter notebooks."
applyTo: "**/*.py"
  - pandas
  - scikit-learn
  - jupyter
---

# Python Coding Standards

This instruction file defines conventions for Python-centric projects, including data science and ML pipelines. Follow these standards to ensure code quality, reproducibility, and maintainability across all Python-based projects.

## Type Hints

Type hints enable static analysis, improve IDE support, and document expected types for function consumers.

- Use type hints for all public function signatures and module-level variables.
- For internal/private functions, use type hints for complex logic (3+ parameters or return types).
- Prefer `Optional[T]`, `Union[T, U]`, and `Literal[...]` from `typing` for clarity.
- Use `from typing import TYPE_CHECKING` for circular import avoidance in forward references.

**Example:**

```python
from typing import Optional, List
from pathlib import Path

def load_dataset(
    path: Path,
    format: str = "csv",
    encoding: Optional[str] = None
) -> dict[str, List]:
    """Load dataset from file."""
    pass
```

## Path Handling

Use `pathlib.Path` exclusively for file and directory operations. Avoid string concatenation or `os.path` for modern Python 3.6+ projects.

- Import via `from pathlib import Path`.
- Use `/` operator for path joins: `Path("data") / "raw" / "file.csv"`.
- Use `.resolve()` to get absolute paths.
- Use `.exists()`, `.is_file()`, `.is_dir()` for checks.
- Use `.read_text()`, `.write_text()` for string I/O; `.read_bytes()` for binary.

**Example:**

```python
from pathlib import Path

data_dir = Path.cwd() / "data" / "raw"
output_file = data_dir / "processed.parquet"

if data_dir.exists():
    for csv_file in data_dir.glob("*.csv"):
        df = pd.read_csv(csv_file)
        # process...
        df.to_parquet(output_file)
```

## Virtual Environments

Project isolation prevents dependency conflicts and enables reproducible builds.

- Always create a project-specific virtual environment using `venv` or `conda`.
- Never install packages globally or into the system Python.
- For new projects, prefer `python -m venv venv` + `pip-tools` or `poetry`.
- For data science/ML projects using scientific stacks, consider `conda` for pre-built binaries (NumPy, SciPy, PyTorch).

**Setup (venv + pip-tools):**

```bash
python -m venv venv
source venv/bin/activate  # Linux/macOS
# or: venv\Scripts\activate  # Windows
pip install pip-tools
pip-compile requirements.in
pip install -r requirements.txt
```

**Setup (conda):**

```bash
conda create -n project-env python=3.11 numpy pandas scikit-learn
conda activate project-env
```

## Dependency Management

Pinned dependencies ensure deterministic environments across machines and CI/CD runs.

- Use `requirements.txt` (for simple projects) or `pyproject.toml` + `poetry` (for libraries and complex projects).
- Always pin exact versions in production: `pandas==2.1.4`, not `pandas>=2.0`.
- Use `pip-tools` to compile `requirements.in` → `requirements.txt` to lock transitive dependencies.
- Update dependencies quarterly; monitor security advisories via `pip-audit` or `Safety`.

**requirements.in example:**

```
pandas>=2.0,<3.0
scikit-learn>=1.3
numpy>=1.24
```

**Compile and lock:**

```bash
pip-compile requirements.in
```

**Poetry (recommended for libraries):**

```toml
[tool.poetry.dependencies]
python = "^3.11"
pandas = "^2.1"
scikit-learn = "^1.3"
```

## Linting and Formatting

Use automated tooling to enforce consistent style and catch bugs.

- **Formatter:** `black` (opinionated, zero-config).
- **Linter:** `ruff` (fast replacement for flake8, isort, etc.) or `flake8` + `pylint` for detailed checks.
- **Type checker:** `mypy` for static type analysis.
- **Security:** `bandit` for security issue detection.

**Setup (ruff + black + mypy):**

```bash
pip install ruff black mypy
```

**.ruff.toml or [tool.ruff] in pyproject.toml:**

```toml
line-length = 100
target-version = "py311"
select = ["E", "F", "W", "I"]  # Errors, pyflakes, warnings, isort
ignore = ["E501"]  # Line too long (handled by black)
```

**Run checks:**

```bash
ruff check .
black .
mypy src/
```

## Imports

Organize imports consistently per PEP 8:

1. Standard library imports.
2. Third-party imports.
3. Local imports.

Blank lines between groups. Use `isort` or `ruff` to automate.

**Example:**

```python
import sys
from pathlib import Path

import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler

from myproject.data import load_dataset
from myproject.models import train_model
```

## Packaging

Distribute Python code as installable packages for reuse and dependency management.

- **For libraries:** Use `pyproject.toml` with `poetry`, `setuptools`, or `hatchling`.
- **For applications:** Use `pyproject.toml` + `pip install -e .` for editable installs during development.
- Include a `py.typed` marker file to signal PEP 561 compliance for type hints.

**pyproject.toml example:**

```toml
[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"

[project]
name = "myproject"
version = "0.1.0"
description = "Data science project"
```

## Testing

Comprehensive tests catch regressions and document expected behavior.

- Use `pytest` for unit and integration tests.
- Place tests in a `tests/` directory mirroring source structure.
- Use `pytest-cov` to measure coverage; aim for 70%+ on critical paths.
- Use fixtures for common setup/teardown (e.g., temporary files, mock data).

**Project structure:**

```
myproject/
├── src/
│   └── myproject/
│       ├── __init__.py
│       ├── data.py
│       └── models.py
├── tests/
│   ├── test_data.py
│   └── test_models.py
├── pyproject.toml
└── README.md
```

**Example test with fixture:**

```python
import pytest
from pathlib import Path
from myproject.data import load_dataset

@pytest.fixture
def sample_csv(tmp_path):
    csv_file = tmp_path / "sample.csv"
    csv_file.write_text("id,value\n1,10\n2,20")
    return csv_file

def test_load_dataset(sample_csv):
    data = load_dataset(sample_csv)
    assert len(data) == 2
    assert "id" in data.columns
```

## Documentation

Use docstrings to document modules, functions, and classes.

- Use Google-style or NumPy-style docstrings for clarity.
- Include type information, parameters, return values, and examples.
- Generate HTML docs via Sphinx for packages.

**Google-style docstring example:**

```python
def calculate_mean(values: List[float]) -> float:
    """Calculate the arithmetic mean of a list of values.

    Args:
        values: List of numeric values.

    Returns:
        The arithmetic mean.

    Raises:
        ValueError: If values list is empty.
    """
    if not values:
        raise ValueError("values cannot be empty")
    return sum(values) / len(values)
```

## Notebooks

See `data-science.instructions.md` for notebook-specific guidance on cell organization, reproducibility, and output management.
