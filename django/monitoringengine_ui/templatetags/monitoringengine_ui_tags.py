# -*- coding: utf-8 -*-
from django import template
from django.contrib.auth.models import User

from monitoringengine_ui.forms import subdomain_include_choices
from monitoringengine_ui.utils import has_perm, get_available_objects_of_type, get_users_for_object, account_subscriptions_number, choose_subdomain_include
from monitoringengine_ui.models import Account, Resource, View, ResourceSubscription


register = template.Library()


@register.filter
def filter_entries_by_region(value, arg):
    return value.filter(subscription__subscription__region=arg)

@register.filter
def filter_entries_by_subscribed(value):
    return value.filter(subscription__datetime_unsubscribed__isnull=True)


@register.filter
def key(value, arg):
    if value and arg in value:
        return value[arg]
    else:
        return None

@register.filter
def regions(resource, query):
    return map(lambda r: r.subscription.region,
               ResourceSubscription.objects.filter(resource=resource,
                                                   subscription__query=query,
                                                   datetime_unsubscribed__isnull=True))




@register.filter
def has_region(regions, region):
    return region in regions



@register.filter
def users(obj, perm=''):
    if perm:
        return get_users_for_object(obj, perm)
    else:
        return (get_users_for_object(obj, 'read') |
                get_users_for_object(obj, 'edit') |
                get_users_for_object(obj, 'manage')).distinct()


register.filter('accounts', get_available_objects_of_type(Account))
register.filter('resources', get_available_objects_of_type(Resource))
register.filter('views', get_available_objects_of_type(View))
register.filter('choose_subdomain_include', choose_subdomain_include)


register.filter('can_read', has_perm('read'))
register.filter('can_edit', has_perm('edit'))
register.filter('can_manage', has_perm('manage'))

register.filter('subscriptions_number', account_subscriptions_number)


@register.filter
def class_verbose(obj):
    return obj._meta.verbose_name


@register.filter
def class_name(obj):
    return obj.__class__.__name__


#TODO: debug-only, убрать из релиза
@register.filter
def permissions(user):
    """
    Получает все имеющиеся у пользователя права

    @type user: User
    @param user: current user
    """
    return user.user_permissions.all()


@register.filter
def report(entry, check):
    q = entry.subscription.reports.filter(datestamp=check)
    if q.exists():
        return q[0].position
    else:
        return None


@register.filter
def decode_idna(value):
    return value.decode("idna")


@register.filter
def subdomain_include_verbose(value):
    return dict(subdomain_include_choices).get(value)
