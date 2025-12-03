from flask import Flask


def create_app(test_config=None):
    """Create and configure the Flask application.

    This is a lightweight factory that provides a clean place to
    migrate application initialization (DB, blueprints, helpers).
    It is intentionally non-invasive: it does not alter the existing
    top-level `app.py`. Use `run.py` to start the app with this factory.
    """
    app = Flask(__name__, static_folder="static", template_folder="templates")

    # Basic default configuration — override from `test_config` or env
    app.config.from_mapping(
        SECRET_KEY="dev-key-change-me",
    )

    if test_config is not None:
        app.config.update(test_config)

    # Register blueprints and extensions here when migrating code in
    # small steps (db, auth, routes, etc.). Example:
    # from .routes import main_bp
    # app.register_blueprint(main_bp)

    return app
