"""Blueprints and route grouping for future migration.

This module defines a small `main_bp` blueprint with simple routes so
you can start using organized route modules without changing `app.py`.
"""
from flask import Blueprint, render_template

main_bp = Blueprint("main", __name__)


@main_bp.route("/")
def index():
    # Use existing templates; data injection is left to the original app.
    return render_template("index.html")
