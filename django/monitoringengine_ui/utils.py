# -*- coding: utf-8 -*-

from monitoringengine_ui.models import ResourceSubscription


def account_subscriptions_number(account):
    return (ResourceSubscription.
            objects.
            filter(datetime_unsubscribed__isnull=True, resource__account=account).
            count())


#функция получилось какой-то полукаррированной из-за использования в нескольких различных фильтрах
#смотри templatetags.monitoringengine_iu_tags
def has_perm(perm):
    def has_perm_on_object(user, obj):
        return (user.
                user_permissions.
                filter(pk=obj.perms.get(perm_type=perm).permission.id).
                exists())

    return has_perm_on_object


def choose_subdomain_include(si):
    if si == 'domain_with_subdomains':
        return "*.*"
    elif si == 'only_subdomains':
        return "*.b"
    elif si == 'strict_domain':
        return "a.b"
    else:
        return '-'

def get_available_objects_of_type(t):
    def objects_for_user(user):
        return t.objects.filter(perms__permission__in=user.user_permissions.all()).distinct()

    return objects_for_user


def get_users_for_object(obj, perm):
    """
    Получает пользователей, которые имеют право perm на объект obj

    @type perm: string
    @param perm: тип доступа к объекту (чтение, запись либо управление пользователями)

    @param obj: объект, для которого поиск пользователей (на данный момент аккаунт, ресурс либо представление)
    """
    return obj.perms.get(perm_type=perm).permission.user_set.all()


def get_object_or_None(model, *args, **kwargs):
    try:
        return model.objects.get(*args, **kwargs)
    except:
        return None
