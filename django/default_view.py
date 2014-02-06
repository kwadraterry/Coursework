from monitoringengine_ui.models import *

for rs in ResourceSubscription.objects.filter(datetime_unsubscribed__isnull=True):
   add_to_default_view(None, rs, None)
