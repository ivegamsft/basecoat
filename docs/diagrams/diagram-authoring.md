# Diagram authoring and migration

## Source and scope

The first migration for #3767 uses [diagram-design](https://github.com/cathrynlavery/diagram-design)
at revision `7a2e22170ee838e859d8142ba825d83f8b6375e6` (MIT; [license](diagram-design.LICENSE)).
The editable source is [diagram-design.html](diagram-design.html); its two static
SVG exports are embedded in the [diagram index](architecture-diagrams-index.md).
No upstream skill, runtime dependency, fonts, or icon assets are distributed.

Inventory at BaseCoat revision `1391bf32b90d06d5c9c4a65d633c48958b7a6d91`:

| Inventory | Migration decision |
|---|---|
| 12 Excalidraw boards in `docs/diagrams` | Refresh asset taxonomy and bootstrap; retain all original boards and links |
| 16 Mermaid blocks in seven dedicated diagram pages | Defer MCP, OAuth, orchestration, workflow loops, and E2E diagrams to separate topic-focused migrations |
| 20 other Mermaid blocks in 17 documentation pages | Keep inline context, workflow references, examples, and the generated dependency graph unchanged |
| Six archived wireframe boards, an archived HTML template, and the live dashboard HTML | Outside this documentation-diagram migration |

The remaining ten dedicated boards cover execution, routing, memory, orchestration,
and dispatch. Defer them to keep this first migration independently reviewable;
delivery/security diagrams need their own trust-boundary review, not a cosmetic redraw.

## Fidelity and design contract

Both diagrams use `doc-inline` (`960 x 600`), balanced detail, and a mixed audience.
The taxonomy is a five-node tree: the root makes the four source families explicit.
Each family's purpose and source path survive; schema field lists remain in the
historical board rather than becoming a competing schema reference.
Bootstrap is an eight-node flowchart with seven directed connections. Preserve start,
four ordered phases, and both exits; replace unbound sketch arrows with explicit routes
and an error decision verified against `scripts/bootstrap.ps1`.
Correct the old memory-index and fixed-token descriptions to SQLite and profile-driven
configuration. Exit zero may include warnings or skipped tests. Optional deployments
and profile-only early exits remain in the script, explicitly outside this core overview.

Use orthogonal connectors, distinct attachment points, a 4px grid, one focal accent,
and no shadows. Shapes and labels carry meaning independently of color.
The offline skin uses the Clawpilot token palette, Segoe UI/Aptos, Consolas technical
labels, and Georgia headings rather than upstream web fonts. Names are 18px and prose
14px for legibility in Markdown embeds. Canvases stay light in both page themes.
HTML scroll regions are keyboard-focusable; print releases the minimum width.

## Editing and export

Edit the named SVG in `diagram-design.html`, not its generated `.svg` sibling.
Obtain the pinned upstream checkout locally; `$upstream` below is its path.
Export only the SVG fragment so HTML theme/chrome does not enter the static asset:

```powershell
$source = Get-Content docs\diagrams\diagram-design.html -Raw
foreach ($slug in @('asset-taxonomy', 'bootstrap-flow')) {
    $fragment = [regex]::Match($source, "(?s)<svg id=`"$slug`".*?</svg>").Value
    if (-not $fragment) { throw "Missing SVG: $slug" }
    $temp = Join-Path ([IO.Path]::GetTempPath()) "$slug.html"
    try {
        [IO.File]::WriteAllText($temp, $fragment)
        python "$upstream\skills\diagram-design\scripts\export_svg.py" $temp "docs\diagrams\$slug.svg" --system-fonts
        if ($LASTEXITCODE -ne 0) { throw "Export failed: $slug" }
    } finally { Remove-Item $temp -ErrorAction Stop }
}
```

Verify XML and accessible title/description references, run upstream
`scripts/verify-geometry.py` on the HTML, and visually inspect the HTML and SVGs at
desktop and phone widths. Validate the actual MkDocs image embeds with
`python -m mkdocs build`; check links and ensure the HTML remains offline-capable.
Do not treat an exported image or exit-zero bootstrap result as deployed behavior proof.
