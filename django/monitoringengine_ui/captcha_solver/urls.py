# -*- coding: utf-8 -*-
from django.conf.urls.defaults import patterns, url

urlpatterns = patterns('monitoringengine_ui.captcha_solver.views',
   url(r'^(?P<captcha_type>\w+)/(?P<captcha_id>\w+)/$',
       "captcha_solver", name="captcha_solver"),
)