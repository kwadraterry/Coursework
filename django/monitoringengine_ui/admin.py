# -*- coding: utf-8 -*-
from django.contrib import admin
from django.contrib.auth.models import Permission

from monitoringengine_ui.models import *


class AccountAdmin(admin.ModelAdmin):

    search_fields = ('name',)

admin.site.register(Account, AccountAdmin)
admin.site.register(Website)
admin.site.register(Resource)
admin.site.register(View)
admin.site.register(Permission)
admin.site.register(ObjectPermission)
admin.site.register(ResourceSubscription)
admin.site.register(Subscription)
admin.site.register(Query)
admin.site.register(Region)
admin.site.register(ViewEntry)
admin.site.register(Report)