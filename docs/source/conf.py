"""Build the PowerBiMIP website locally and on Read the Docs."""
import os

project = "PowerBiMIP"
copyright = "2026, Yemin Wu"
author = "Yemin Wu"
language = "en"
extensions = ["myst_parser"]
myst_enable_extensions = ["colon_fence", "dollarmath"]
templates_path = ["_templates"]
exclude_patterns = []
html_theme = "furo"
html_title = "PowerBiMIP"
html_logo = "_static/PowerBiMIP_logo.svg"
html_favicon = "_static/favicon.svg"
html_static_path = ["_static"]
html_css_files = ["custom.css"]
html_js_files = ["site.js"]
html_baseurl = os.environ.get("READTHEDOCS_CANONICAL_URL", "https://docs.powerbimip.com/en/latest/")
html_theme_options = {
    "sidebar_hide_name": True,
    "source_repository": "https://github.com/GreatTM/PowerBiMIP/",
    "source_branch": "main",
    "source_directory": "docs/source/",
    "top_of_page_buttons": ["edit"],
    "light_css_variables": {
        "color-brand-primary": "#087f79",
        "color-brand-content": "#087f79",
        "color-background-primary": "#fcfcfa",
        "color-background-secondary": "#f3f5f1",
        "color-background-border": "#dde4de",
        "color-foreground-primary": "#203737",
        "color-foreground-secondary": "#526461",
        "color-foreground-muted": "#5d706b",
        "color-link-underline": "#94bcb4",
        "color-link--visited": "#087f79",
        "color-link--visited--hover": "#b9511c",
        "color-link-underline--visited": "#94bcb4",
        "font-stack": '"Inter", "Avenir Next", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
        "font-stack--monospace": '"SFMono-Regular", Consolas, "Liberation Mono", monospace',
    },
    "dark_css_variables": {
        "color-brand-primary": "#70dac5",
        "color-brand-content": "#70dac5",
        "color-background-primary": "#101b1d",
        "color-background-secondary": "#142225",
        "color-background-border": "#2c4041",
        "color-foreground-primary": "#edf3ed",
        "color-foreground-secondary": "#b6c8c2",
        "color-foreground-muted": "#a0b6ad",
        "color-link-underline": "#476e67",
        "color-link--visited": "#70dac5",
        "color-link--visited--hover": "#f1a26d",
        "color-link-underline--visited": "#476e67",
    },
}
