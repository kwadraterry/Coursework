import os
import sys

sys.path[0:0] = [os.path.expanduser("~/django")]

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "monitoringengine_ui.settings")

from django.core.wsgi import get_wsgi_application

application = get_wsgi_application()
