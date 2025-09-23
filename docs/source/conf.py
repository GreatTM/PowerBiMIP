# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'PowerBiMIP'
copyright = '2025, Yemin Wu'
author = 'Yemin Wu'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'myst_parser',
    'sphinx_rtd_theme',
]

templates_path = ['_templates']
exclude_patterns = []



# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output
# -- Options for HTML output -------------------------------------------------

html_theme = 'sphinx_rtd_theme'

# Add this line to set the logo
html_logo = '_static/PowerBiMIP_logo.svg'

html_static_path = ['_static']
