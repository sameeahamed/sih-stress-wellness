"""Shared pytest fixtures and sys.path setup.

Having this file at the backend/ root makes pytest add ``backend/`` to
``sys.path`` so ``app.*`` imports resolve without installation.
"""