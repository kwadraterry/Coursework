# -*- coding: utf-8 -*-
from django.db import connection
from monitoringengine_ui.models import *

cursor = connection.cursor()
accmap = {1: 1, 2: 2}
cursor.execute('''Select account_id,website_id,note from accounts_websites''')
for res in cursor.fetchall():
    account = Account.objects.get(pk=accmap[res[0]])
    website = Website.objects.get(pk=res[1])
    note = res[2] or ''
    Resource.objects.create(account=account, website=website, note=note)
