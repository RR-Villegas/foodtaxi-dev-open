"""Minimal entrypoint that uses the `foodtaxi` factory.

This file is optional — it demonstrates a clean way to run the app
without touching the existing `app.py`. To run:

    python run.py

"""
import os

from foodtaxi import create_app


def main():
    env_port = int(os.environ.get("PORT", 5000))
    app = create_app()
    app.run(host="0.0.0.0", port=env_port, debug=True)


if __name__ == "__main__":
    main()
