# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'DCS Dynamic Campaign Tools'
copyright = '2023, Jonathan Toppins'
author = 'Jonathan Toppins'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
        'sphinx.ext.duration',
        'sphinxcontrib.luadomain',
        'sphinx_lua',
        'sphinx_markdown_builder',
        'sphinx.ext.autodoc',
        'sphinx.ext.autosummary',
    ]

templates_path = ['_templates']
exclude_patterns = ['.gitignore',]

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'alabaster'
#html_static_path = ['_static']

# -- Options for LUA source --------------------------------------------------
# https://github.com/boolangery/sphinx-lua
lua_source_path = ["../src/dct/", "../src/dct.lua",]
lua_source_encoding = 'utf8'
lua_source_comment_prefix = '---'
lua_source_use_emmy_lua_syntax = True
lua_source_private_prefix = '_'
