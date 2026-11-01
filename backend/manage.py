#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import subprocess
import sys


def utiliser_env_du_projet():
    """`python manage.py …` fonctionne sans activer l'environnement : si le Python
    utilisé n'est pas celui de backend/env (ex. conda « base »), on relance avec lui."""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    for env_name in ('venv', 'env'):
        env_dir = os.path.join(base_dir, env_name)
        if sys.platform == 'win32':
            env_python = os.path.join(env_dir, 'Scripts', 'python.exe')
        else:
            env_python = os.path.join(env_dir, 'bin', 'python')
        deja_dans_env = os.path.realpath(sys.prefix) == os.path.realpath(env_dir)
        if os.path.isfile(env_python) and not deja_dans_env and not os.environ.get('SENALERT_ENV_RELANCE'):
            os.environ['SENALERT_ENV_RELANCE'] = '1'
            try:
                if sys.platform == 'win32':
                    # Sous Windows, os.execv rend la main tout de suite : le code de
                    # sortie serait perdu et le serveur détaché de la console.
                    sys.exit(subprocess.call([env_python, *sys.argv]))
                os.execv(env_python, [env_python, *sys.argv])
            except OSError:
                pass


def main():
    """Run administrative tasks."""
    utiliser_env_du_projet()
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
    if len(sys.argv) > 1 and sys.argv[1] == 'test':
        os.environ['SENALERT_TESTING'] = '1'  # désactive Firebase et les appels externes
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()
