# Product Definition

The repository-level `PRODUCT.md` (at the repository root; not copied by
consumer sync since this reference file is) is the canonical product
definition for BaseCoat. It uses a BaseCoat-specific sectioned structure in
CommonMark that captures product context, users, purpose, boundaries, and
design principles for this repository.

## How downstream repositories use it

During onboarding, inventory the downstream repository's existing
`PRODUCT.md` before proposing design or UX changes. If it is missing, propose a
repository-owned definition rather than silently creating one. Use the
`design:` onboarding debate to compare the proposed product definition with
the repository's current UI, UX, information architecture, accessibility
requirements, and design-system evidence.

The BaseCoat file is a reference for the operating model, not a template to
copy over a downstream product definition. Tools must preserve sections,
frontmatter, and machine islands they do not own.
