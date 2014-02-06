from monitoringengine_ui.models import Account


def grant_all_permissions(user):
    for acc in Account.objects.all():
        for perm in acc.perms.all():
            user.user_permissions.add(perm.permission)
