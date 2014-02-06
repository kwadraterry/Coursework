from django.db import connection
from monitoringengine_ui.models import *

cursor = connection.cursor()
cursor.execute('''Select name,max_subscriptions_number from accounts''')
for acc in cursor.fetchall():
    Account.objects.create(name=acc[0], max_subscriptions_number=0)
