# -*- coding: utf-8 -*-
from django.conf.urls.defaults import patterns, include, handler404, handler500, url
from django.conf import settings
from django.contrib import admin
from django.contrib.staticfiles.urls import staticfiles_urlpatterns

from monitoringengine_ui.views import ResourceView, AccountView, ViewView, \
    UserCreate, UserUpdate, PositionsView, SubscriptionCreate

handler404
handler500

admin.autodiscover()
urlpatterns = patterns('')

urlpatterns += staticfiles_urlpatterns()
urlpatterns += patterns('',
    (r'^media/(?P<path>.*)$', 'django.views.static.serve',
        {'document_root': settings.MEDIA_ROOT}),
)

urlpatterns += patterns('',
    (r'^admin/', include(admin.site.urls)),
    (r'social_auth/', include('social_auth.urls')),
    (r'auth/', include('monitoringengine_ui.authorisation.urls')),
    (r'^captcha_solver/', include("monitoringengine_ui.captcha_solver.urls")),
    url(r'^$', 'monitoringengine_ui.views.frontpage', name="frontpage"),

    url(r'^account/(?P<pk>\d+)/$', AccountView.as_view(), name='account'),
    url(r'^account/(?P<pk>\d+)/add_resource/$', 'monitoringengine_ui.views.add_resource_for_account',
        name='add_resource'),
    url(r'^resource/(?P<pk>\d+)/$', ResourceView.as_view(), name='resource'),
    url(r'^resource/(?P<pk>\d+)/add_subscription/$', SubscriptionCreate.as_view(), name='add_subscription'),
    url(r'^resource/(?P<pk>\d+)/add_view/$', 'monitoringengine_ui.views.add_view', name='create_view'),
    url(r'^resource/(?P<resource_id>\d+)/add_query/$', 'monitoringengine_ui.views.add_query', name="add_query"),
    url(r'^resource/(?P<resource_id>\d+)/change_search_depth/$', 'monitoringengine_ui.views.change_search_depth', name="change_search_depth"),
    url(r'^resource/(?P<resource_id>\d+)/change_subdomain_include/$', 'monitoringengine_ui.views.change_subdomain_include', name="change_subdomain_include"),
    url(r'^resource/(?P<resource_id>\d+)/change_all/$', 'monitoringengine_ui.views.change_all', name="change_all"),
    url(r'^resource/(?P<resource_id>\d+)/edit/$',
        'monitoringengine_ui.views.edit_query', name="edit_resource"),
    url(r'^resource/(?P<pk>\d+)/positions_with_regions/$', 'monitoringengine_ui.views.positions_with_regions', name='positions_with_regions'),
    url(r'^resource/(?P<pk>\d+)/check_fresh/$', 'monitoringengine_ui.views.view_check_fresh', name='check_fresh'),
    url(r'^resource/(?P<pk>\d+)/save/$', 'monitoringengine_ui.views.save_view', name='save_view'),
    url(r'^resource/(?P<pk>\d+)/sync/$', 'monitoringengine_ui.views.view_sync', name='view_sync'),
    url(r'^resource/(?P<pk>\d+)/delete_entries/$','monitoringengine_ui.views.delete_entries', name='delete_entries'),
    url(r'^resource/(?P<pk>\d+)/positions_slider/$', 'monitoringengine_ui.views.positions_slider', name="positions_slider"),
    url(r'^resource/(?P<pk>\d+)/positions/$', 'monitoringengine_ui.views.positions_view', name='positions'),


    url(r'^view/(?P<pk>\d+)/$', ViewView.as_view(), name='view'),
    url(r'^view/(?P<pk>\d+)/export/$', 'monitoringengine_ui.views.export', name='export'),
    url(r'^view/(?P<pk>\d+)/add_entries/$', 'monitoringengine_ui.views.add_entries_to_view', name='add_entries'),


    url(r'^(?P<action>\w+)_perm/(?P<model>\w+)/(?P<pk>\d+)/(?P<username>[\w.@+-]+)/(?P<perm_type>\w+)/$',
        'monitoringengine_ui.views.manage_perm', name='manage_perm'),

    url(r'^add_user_to_object/(?P<model>\w+)/(?P<pk>\d+)/$',
        'monitoringengine_ui.views.add_user_to_object', name='add_user_to_object'),

    (r'^robots.txt$', 'django.views.generic.simple.direct_to_template', {'template': 'robots.txt', 'mimetype': 'text/plain'}),
    url(r'^websites/delete_website/(?P<website_id>\d+)/$', 'monitoringengine_ui.views.delete_website', name="delete_website"),
    url(r'^resource/(?P<resource_id>\d+)/query/(?P<query_id>\d+)/$',
        'monitoringengine_ui.views.resource_query', name="resource_query"),
    url(r'resource/(?P<resource_id>\d+)/region/(?P<region_id>\d+)/$',
        'monitoringengine_ui.views.region_subscriptions', name="region_subscriptions"),
    url(r'^websites/positions_for_website/(?P<website_id>\d+)/$',
        'monitoringengine_ui.views.positions_for_website', name="positions_for_website"),
    url(r'^websites/delete_query/(?P<yandex_account_subscription_id>\d+)/$', 'monitoringengine_ui.views.delete_query',
        name="delete_query"),
    url(r'resource/(?P<resource_id>\d+)/change_region/$', 'monitoringengine_ui.views.change_region', name="change_region"),
    url(r'^users/add_user/$', UserCreate.as_view(), name="add_user"),
    url(r'^users/change_client/(?P<user_id>\d+)/$', UserUpdate.as_view(), name="change_client"),
)

