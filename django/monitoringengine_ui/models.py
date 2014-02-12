# -*- coding: utf-8 -*-
from django.db.models.signals import post_save, post_delete, m2m_changed
from django.contrib.contenttypes import generic
from django.contrib.contenttypes.models import ContentType
from django.contrib.auth.models import Permission, User
from django.db import models


def unmanaged_meta(table):
    class UnmanagedMeta:
        db_table = table
        managed = False
    return UnmanagedMeta


class ObjectPermission(models.Model):
    permission = models.OneToOneField(Permission, related_name='object_permission')
    perm_type = models.CharField(verbose_name=u"Тип права", max_length=10)

    content_type = models.ForeignKey(ContentType,
                                     limit_choices_to={'model__in': ['account', 'resource', 'view']})
    object_id = models.PositiveIntegerField()
    content_object = generic.GenericForeignKey('content_type', 'object_id')

    class Meta:
        unique_together = (('perm_type', 'content_type', 'object_id'),)

    def __unicode__(self):
        return u'%s | %s' % (self.perm_type, self.content_object.__unicode__())


class Account(models.Model):
    name = models.CharField(verbose_name=u"Название", max_length=255)
    max_subscriptions_number = models.IntegerField(verbose_name=u"Количество запросов", default=0)
    perms = generic.GenericRelation(ObjectPermission)

    class Meta:
        verbose_name = u"аккаунт"
        verbose_name_plural = u"аккаунты"

    @property
    def parent(self):
        return None

    @property
    def children(self):
        return self.resources

    def get_absolute_url(self):
        from django.core.urlresolvers import reverse

        return reverse("account", kwargs={'pk': self.id})

    def __unicode__(self):
        return self.name


class Website(models.Model):
    hostname = models.CharField(verbose_name=u"Имя хоста", max_length=250)

    class Meta(unmanaged_meta('websites')):
        verbose_name = u"веб-сайт"
        verbose_name_plural = u"веб-сайты"

    def __unicode__(self):
        return self.hostname


class Resource(models.Model):
    account = models.ForeignKey(Account, related_name='resources')
    website = models.ForeignKey(Website, related_name='resources')
    note = models.CharField(verbose_name=u"Note", max_length=250)
    perms = generic.GenericRelation(ObjectPermission)

    class Meta:
        verbose_name = u"ресурс"
        verbose_name_plural = u"ресурсы"

    @property
    def subscriptions(self):
        # нет реверс-лукапа для этой пары моделей, делаем вручную
        return self.resource_subscriptions.filter(datetime_unsubscribed__isnull=True)

    @property
    def parent(self):
        return self.account

    @property
    def children(self):
        return self.views

    def get_absolute_url(self):
        from django.core.urlresolvers import reverse

        return reverse("resource", kwargs={'pk': self.id})

    def __unicode__(self):
        return self.website.__unicode__().decode("idna")


class View(models.Model):
    name = models.CharField(verbose_name=u'Название', max_length=255)
    last_changed = models.DateTimeField(auto_now_add=True)
    resource = models.ForeignKey(Resource, related_name='views')
    perms = generic.GenericRelation(ObjectPermission)

    class Meta:
        verbose_name = u"представление"
        verbose_name_plural = u"представленьица-с"

    @property
    def parent(self):
        return self.resource

    @property
    def children(self):
        return None

    def get_absolute_url(self):
        from django.core.urlresolvers import reverse

        return reverse("view", kwargs={'pk': self.id})

    def __unicode__(self):
        return self.name


class Query(models.Model):
    querystring = models.CharField(verbose_name=u"Строка поиска", max_length=250)

    class Meta(unmanaged_meta('queries')): pass

    def __unicode__(self):
        return self.querystring


class Region(models.Model):
    name = models.CharField(verbose_name=u"Регион", max_length=250)
    code = models.IntegerField(verbose_name=u"Код региона")

    class Meta(unmanaged_meta('yandex_regions')): pass

    def __unicode__(self):
        return self.name


class Subscription(models.Model):
    search_depth = models.IntegerField(verbose_name=u"Глубина поиска")
    query = models.ForeignKey(Query, related_name='subscriptions')
    region = models.ForeignKey(Region, related_name='subscriptions', db_column='yandex_region_id')

    class Meta(unmanaged_meta('yandex_subscriptions')): pass

    def __unicode__(self):
        return self.query.__unicode__()


class Quantity(models.Model):
    subscription = models.ForeignKey(Subscription, related_name='quantities', db_column='yandex_subscription_id')
    quantity = models.IntegerField(db_column='common_quantity')
    timestamp = models.DateTimeField()

    class Meta(unmanaged_meta('yandex_wordstat')):
        get_latest_by = "timestamp"


class SubdomainIncludeField(models.Field):
    def db_type(self, connection):
        return 'subdomain_include'


class ResourceSubscription(models.Model):
    datetime_subscribed = models.DateTimeField()
    datetime_unsubscribed = models.DateTimeField(blank=True, null=True)
    search_depth = models.IntegerField(verbose_name=u"Глубина поиска")
    subdomain_include = SubdomainIncludeField()
    # не рекомендуется использовать реверс-лукап для ресурса, доступ к подпискам будем получать через property
    resource = models.ForeignKey(Resource, related_name='resource_subscriptions')
    subscription = models.ForeignKey(Subscription,
                                     related_name='resource_subscriptions',
                                     db_column='yandex_subscription_id')

    class Meta(unmanaged_meta('yandex_accounts_subscriptions')): pass


class Report(models.Model):
    resource_subscription = models.ForeignKey(ResourceSubscription,
                                              related_name='reports',
                                              db_column='yandex_account_subscription_id')
    position = models.IntegerField(verbose_name=u'Позиция')
    search_depth = models.IntegerField(verbose_name=u'Глубина поиска')
    datestamp = models.DateField()

    class Meta(unmanaged_meta('yandex_reports')):
        ordering = ['datestamp']


class ViewEntry(models.Model):
    sorting_order = models.IntegerField(verbose_name='Приоритет при сортировке', default=0)
    view = models.ForeignKey(View, related_name='entries')
    subscription = models.ForeignKey(ResourceSubscription)

    class Meta:
        ordering = ['sorting_order']


class Profile(models.Model):
    user = models.OneToOneField('auth.User', verbose_name=u'Пользователь')
    email_verified = models.BooleanField(u'E-mail достоверный', default=False)


#
# далее идёт код привязки хэндлеров к сигналам
#


def create_perm_on_object(obj, perm_type):
    if not obj.perms.filter(perm_type=perm_type).exists():
        ct = ContentType.objects.get_for_model(obj.__class__)
        name_parts = [perm_type, obj.__class__.__name__.lower(), str(obj.id)]
        perm, _ = Permission.objects. \
            get_or_create(name=' '.join(name_parts),
                          content_type=ct,
                          codename='_'.join(name_parts))
        obj_perm = ObjectPermission.objects. \
            create(perm_type=perm_type,
                   permission=perm,
                   content_type=ct,
                   content_object=obj)
        obj_perm.save()


def create_all_permissions_on_object(sender, instance, created, **kwargs):
    if created:
        create_perm_on_object(instance, 'read')
        create_perm_on_object(instance, 'edit')
        create_perm_on_object(instance, 'manage')
        if instance.parent:
            for p in instance.parent.perms.all():
                for user in p.permission.user_set.all():
                    user.user_permissions.add(instance.perms.get(perm_type=p.perm_type).permission)


post_save.connect(create_all_permissions_on_object, sender=Account, dispatch_uid="create_perms_for_account")
post_save.connect(create_all_permissions_on_object, sender=Resource, dispatch_uid="create_perms_for_resource")
post_save.connect(create_all_permissions_on_object, sender=View, dispatch_uid="create_perms_for_view")


def delete_related_permission(sender, instance, **kwargs):
    instance.permission.delete()


post_delete.connect(delete_related_permission, sender=ObjectPermission, dispatch_uid='delete_related_permission')


def add_to_default_view(sender, instance, created, **kwargs):
    """
    @type instance: ResourceSubscription
    """
    view, c = instance.resource.views.get_or_create(name=u"Представление по умолчанию")
    view.entries.get_or_create(subscription=instance)


post_save.connect(add_to_default_view, sender=ResourceSubscription, dispatch_uid='add_to_default_view')


def propagate_permissions(sender, instance, action, reverse, model, pk_set, **kwargs):
    if action == 'post_add':
        if not reverse:
            for pk in pk_set:
                p = model.objects.get(pk=pk)  # @type p: Permission
                if hasattr(p, 'object_permission') and p.object_permission.content_object.children:
                    for c in p.object_permission.content_object.children.all():
                        child_perm = c.perms.get(perm_type=p.object_permission.perm_type).permission
                        instance.user_permissions.add(child_perm)
        elif hasattr(instance, 'object_permission') and instance.object_permission.content_object.children:
            for pk in pk_set:
                u = model.objects.get(pk=pk)  # @type u: User
                for c in instance.object_permission.content_object.children.all():
                    child_perm = c.perms.get(perm_type=instance.object_permission.perm_type).permission
                    u.user_permissions.add(child_perm)


m2m_changed.connect(propagate_permissions,
                    sender=User.user_permissions.through,
                    dispatch_uid='propagate_user_permissions')
