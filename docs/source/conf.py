"""Build the PowerBiMIP website locally and on Read the Docs."""
import os
from pathlib import PurePosixPath

from docutils import nodes

project = "PowerBiMIP"
copyright = "2026, Yemin Wu"
author = "Yemin Wu"
language = "en"
extensions = ["myst_parser"]
myst_enable_extensions = ["colon_fence", "dollarmath"]
myst_heading_anchors = 2
templates_path = ["_templates"]
exclude_patterns = []
html_theme = "furo"
html_title = "PowerBiMIP"
html_favicon = "_static/favicon.svg"
html_static_path = ["_static"]
html_css_files = ["custom.css"]
html_js_files = [("site.js", {"defer": "defer"})]
html_baseurl = os.environ.get("READTHEDOCS_CANONICAL_URL", "https://docs.powerbimip.com/en/latest/")
html_sidebars = {
    "**": [
        "sidebar/brand.html",
        "sidebar/search.html",
        "sidebar/scroll-start.html",
        "sidebar/navigation.html",
        "sidebar/project-link.html",
        "sidebar/ethical-ads.html",
        "sidebar/scroll-end.html",
        "sidebar/variant-selector.html",
    ],
}

theme_variables = {
    "font-stack": '"Source Sans 3", system-ui, -apple-system, "Segoe UI", sans-serif',
    "font-stack--headings": "var(--font-stack)",
    "font-stack--monospace": 'ui-monospace, "SFMono-Regular", Consolas, "Liberation Mono", monospace',
    "color-background-primary": "var(--pb-canvas)",
    "color-background-secondary": "var(--pb-surface)",
    "color-background-border": "var(--pb-border)",
    "color-foreground-primary": "var(--pb-ink)",
    "color-foreground-secondary": "var(--pb-muted)",
    "color-foreground-muted": "var(--pb-muted)",
    "color-brand-primary": "var(--pb-link)",
    "color-brand-content": "var(--pb-link)",
    "color-link": "var(--pb-link)",
    "color-link--hover": "var(--pb-link-hover)",
    "color-link--visited": "var(--pb-visited)",
    "color-link--visited--hover": "var(--pb-link-hover)",
    "color-link-underline": "currentColor",
    "color-link-underline--hover": "currentColor",
    "color-link-underline--visited": "currentColor",
    "color-link-underline--visited--hover": "currentColor",
    "color-sidebar-link-text": "var(--pb-ink)",
    "color-sidebar-link-text--top-level": "var(--pb-ink)",
    "color-sidebar-item-background--current": "var(--pb-wash)",
    "color-sidebar-item-background--hover": "var(--pb-wash)",
    "color-sidebar-search-background": "var(--pb-canvas)",
    "color-sidebar-search-background--focus": "var(--pb-canvas)",
    "color-sidebar-search-text": "var(--pb-ink)",
    "color-sidebar-search-icon": "var(--pb-muted)",
    "color-inline-code-background": "var(--pb-surface)",
    "color-code-background": "var(--pb-surface)",
    "color-code-foreground": "var(--pb-ink)",
    "color-table-header-background": "var(--pb-surface)",
    "color-table-border": "var(--pb-border)",
    "color-highlight-on-target": "var(--pb-wash)",
    "sidebar-item-font-size": "0.9375rem",
    "sidebar-caption-font-size": "0.875rem",
    "sidebar-search-input-font-size": "0.9375rem",
    "admonition-font-size": "1rem",
    "admonition-title-font-size": "1rem",
}

html_theme_options = {
    "sidebar_hide_name": True,
    "source_repository": "https://github.com/GreatTM/PowerBiMIP/",
    "source_branch": "main",
    "source_directory": "docs/source/",
    "top_of_page_buttons": ["edit"],
    "light_css_variables": {
        **theme_variables,
        "pb-canvas": "#fcfbf8",
        "pb-surface": "#f3f4f0",
        "pb-ink": "#202724",
        "pb-muted": "#4e5a54",
        "pb-link": "#09645d",
        "pb-link-hover": "#064a44",
        "pb-visited": "#455682",
        "pb-on-link": "#ffffff",
        "pb-border": "#dadfd9",
        "pb-control": "#76837b",
        "pb-focus": "#a04419",
        "pb-wash": "#e6f0eb",
        "pb-warm": "#f8eee4",
    },
    "dark_css_variables": {
        **theme_variables,
        "pb-canvas": "#151817",
        "pb-surface": "#1d2220",
        "pb-ink": "#eeeeeb",
        "pb-muted": "#b8c1bc",
        "pb-link": "#8fd6c8",
        "pb-link-hover": "#b0e7dc",
        "pb-visited": "#bfbaec",
        "pb-on-link": "#102221",
        "pb-border": "#354039",
        "pb-control": "#74867c",
        "pb-focus": "#f4ac7c",
        "pb-wash": "#23352f",
        "pb-warm": "#332820",
    },
}


def prepare_case_figure(app, doctree):
    if app.builder.format != "html":
        return
    for image in doctree.findall(nodes.image):
        path = PurePosixPath(image["uri"])
        if path.parent != PurePosixPath("_static/figures") or path.stem != "powerbimip-mibs-time-to-gap":
            continue
        # Normalize the existing figure reference before Sphinx collects its assets.
        image["uri"] = str(path.with_suffix(".webp"))
        image["width"], image["height"] = "3355", "2451"
        image["loading"] = "lazy"


def setup(app):
    app.connect("doctree-read", prepare_case_figure, priority=400)
    return {"parallel_read_safe": True, "parallel_write_safe": True}
