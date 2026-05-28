---
title: Data Science / ML / Notebook Instruction
type: instruction
description: "Conventions for data science, ML, and notebook-driven projects using Jupyter, pandas, scikit-learn, DuckDB, and the medallion lakehouse architecture."
applyTo: "**/*.{py,ipynb}"
---

# Data Science / ML / Notebook Instruction

Conventions for reproducible, collaborative data science projects. Follow these rules to ensure notebooks execute reliably, data pipelines are auditable, and models are reproducible.

## Project Structure

- Separate raw/bronze/silver/gold data layers (medallion pattern).
- Keep code in `src/` as importable modules; notebooks call `src/` functions.
- Pin all dependencies with exact versions (`requirements.txt` or `environment.yml`).
- See [notebook-conventions.md](references/data-science/notebook-conventions.md) for the canonical directory layout.

## Notebook Hygiene

- **Idempotency:** Notebooks must run top-to-bottom without errors. Use Kernel → Restart & Run All before committing.
- **No hidden state:** Never rely on cells executed out-of-order.
- **Clear outputs:** Strip cell outputs before committing (`nbstripout`).
- **First cell:** Set random seeds, paths, and config. No side-effects.

## Reproducibility

- **Fixed seeds:** `np.random.seed(42)`, `torch.manual_seed(42)`.
- **Data provenance:** Document sources, download dates, and checksums.
- **Version-control scripts, not outputs:** Commit `.py` and `.ipynb`; not model files or large CSVs.

## Data Splits & Leakage Prevention

- Stratify classification splits: `train_test_split(..., stratify=y)`.
- Time-series data: use `TimeSeriesSplit`; never shuffle temporal data.
- Fit scalers/encoders on training data only; `transform()` on test data.
- See [feature-engineering-and-training.md](references/data-science/feature-engineering-and-training.md) for examples.

## Feature Engineering

- One transformation per function; document each feature's meaning.
- Chain transformations via `sklearn.pipeline.Pipeline`.
- Separate scaling, encoding, and domain-specific logic into distinct steps.

## Model Evaluation

- Log metrics (accuracy, AUC, F1) to `results/metrics.json`.
- Save models to `results/models/` using joblib or ONNX.
- Always record a baseline for comparison.
- Plot confusion matrix and ROC curve for all classifiers.

## Data Validation

- Use `pandera` for schema validation: types, nullability, and value ranges.
- Check for missing values and duplicates before each pipeline stage.

## Medallion Architecture

- **Bronze:** Raw ingested data — minimal transformation.
- **Silver:** Cleaned, deduplicated, schema-enforced, PII removed.
- **Gold:** Aggregated, business-ready, denormalized.
- Use DuckDB for fast local SQL on Parquet/pandas without data movement.
- See [medallion-and-duckdb.md](references/data-science/medallion-and-duckdb.md) for patterns and DuckDB examples.

## Reference Files

| File | Contents |
|---|---|
| [notebook-conventions.md](references/data-science/notebook-conventions.md) | Project structure, idempotency, cell hygiene, Fabric/Jupyter/testing |
| [medallion-and-duckdb.md](references/data-science/medallion-and-duckdb.md) | Medallion layers, DuckDB patterns, pandera validation |
| [feature-engineering-and-training.md](references/data-science/feature-engineering-and-training.md) | Train/test splits, feature pipelines, model evaluation |

## See Also

- `python.instructions.md` — General Python coding standards (type hints, linting, packaging).
- `testing.instructions.md` — General testing patterns and CI/CD integration.
