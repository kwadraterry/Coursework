# -*- coding: utf-8 -*-
from django.db import connection
import datetime
from monitoringengine_ui.models import *

accmap = {1: 1, 2: 2}
cursor = connection.cursor()
cursor.execute('''Select id, account, website from ACC''')
t1 = datetime.datetime.now()
for acc in cursor.fetchall():
    sub = ResourceSubscription.objects.get(pk=acc[0])
    website = Website.objects.get(pk=acc[2])
    account = Account.objects.get(pk=accmap[acc[1]])
    resource = Resource.objects.get(account=account, website=website, note='')
    sub.resource = resource
    sub.save()
    if not sub.datetime_unsubscribed:
        add_to_default_view(Resource, sub, False)  # выглядит тупо, но сигналы отчего-то не срабатывают
t2 = datetime.datetime.now() - t1
print t2
