# -*- coding: utf-8 -*-
import datetime
import json
import re
import dateutil.parser
from ast import literal_eval
from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test, permission_required
from django.contrib.auth.models import User
from django.contrib.auth.views import redirect_to_login
from django.contrib.formtools.wizard import FormWizard
from django.core.urlresolvers import reverse
from django.shortcuts import render_to_response, get_object_or_404
from django.template.context import RequestContext
from django.http import Http404, HttpResponseRedirect, HttpResponse, HttpResponseBadRequest
from django.db import connection
from django.db.models.loading import get_model
from django.views.generic.base import TemplateView
from django.views.generic.detail import DetailView
from django.utils.decorators import method_decorator
from django.views.generic.edit import CreateView, UpdateView

from odslib import ODS

from monitoringengine_ui.forms import SiteAddForm, AddYandexQueryForm, \
    WebsiteSearchResultsForm, AddQueryForm, ChangeWebsiteNoteForm, AddSubscriptionForm
from monitoringengine_ui.models import Account, Resource, Query, Website, View, Region, Subscription, ResourceSubscription, ViewEntry
from monitoringengine_ui.utils import account_subscriptions_number, get_object_or_None, has_perm, choose_subdomain_include


def func_or(*funcs):
    def result(*args, **kwargs):
        return reduce(lambda f, g: f(*args, **kwargs) or g(*args, **kwargs), funcs)
    return result


def any_permission_required(*perms):
    return user_passes_test(lambda u: any(u.has_perm(perm) for perm in perms))


def build_permission_name(content_type, perm, object_id):
    return "%(app)s.%(perm)s_%(type)s_%(id)s" % \
           {'app': 'monitoringengine_ui', 'perm': perm, 'type': content_type, 'id': object_id}


def permission_on_object_required(content, perm='read', build_perm=build_permission_name):
    """
    Декорированное представление проверяет наличие у пользователя указанного perm
    на объект типа content_type
    id объекта должен передаваться представлению keyword-параметром {content-type}_id

    content

    perm -- "read", "edit" или "manage_users"
    Например:
    @permission_on_object_required('account', 'read')
    def account(request, account_id)
    """

    def decorator(view_func):
        def _wrapped_view(request, *args, **kwargs):
            _id = content_type + '_id'
            if _id in kwargs:
                if request.user.has_perm(build_perm(content_type, perm, kwargs[_id])):
                    return view_func(request, *args, **kwargs)
                return redirect_to_login(request.get_full_path())
            raise Http404

        return _wrapped_view

    return decorator


class PermissionOnObjectRequiredMixin():
    pass


@login_required
def frontpage(request):
    return render_to_response("monitoringengine_ui/frontpage3.html", RequestContext(
        request,
        {'user': request.user, }))


class AccountView(DetailView):
    template_name = "monitoringengine_ui/account.html"
    model = Account

    @method_decorator(login_required)
    def dispatch(self, request, *args, **kwargs):
        self.msg = messages.get_messages(request)
        return super(AccountView, self).dispatch(request, *args, **kwargs)

    def get_context_data(self, **kwargs):
        context = super(AccountView, self).get_context_data(**kwargs)
        context.update({'form': SiteAddForm(), 'messages': self.msg})
        return context


@login_required
def add_resource_for_account(request, pk):
    account = get_object_or_404(Account, pk=pk)
    if request.method == "POST":
        form = SiteAddForm(request.POST)
        if form.is_valid():
            hostname = form.cleaned_data.get('hostname')
            website = get_object_or_None(Website, hostname=hostname)
            if not website:
                website = Website.objects.create(hostname=hostname)
            resource = get_object_or_None(Resource, account=account, website=website)
            if not resource:
                resource = Resource.objects.create(account=account, website=website, note=u"")
                messages.add_message(request, messages.SUCCESS, u"Ресурс %s был добавлен" % resource.website.hostname)
            else:
                messages.add_message(request, messages.WARNING, u"Ресурс %s уже существует" % resource.website.hostname)
        else:
            messages.add_message(request, messages.ERROR, u"Некорректное имя хоста", extra_tags='danger')
    return HttpResponseRedirect(reverse("account", kwargs={'pk': pk}) + '#sites')


@login_required
@permission_required("bigeye.owner")
def delete_website(request, website_id):
    account = request.user.profile.account
    cursor = connection.cursor()
    if request.is_ajax():
        cursor.execute("""SELECT hostname FROM websites WHERE Id=%s""", [website_id])
        url = cursor.fetchone()
        #        удаляем все привязки аккаунта к подпискам
        cursor.execute("""
            UPDATE yandex_resources_subscriptions SET datetime_unsubscribed = %s
            WHERE account_id = %s AND website_id = %s
        """, [datetime.datetime.now(), account.id, website_id])
        #        удаляем привязку к сайту
        cursor.execute("""DELETE FROM resources WHERE
            website_id=%s AND account_id""", [website_id, account.id])
        connection.connection.commit()
        messages.add_message(request, messages.INFO,
                             u"Сайт %s был удален. Также были удалены все запросы, связанные с ним" % url)
        return HttpResponse(json.dumps({'deleted': True}),
                            content_type='application/json')
    return HttpResponse(json.dumps({'deleted': False}),
                        content_type='application/json')


@login_required
def resource_query(request, resource_id, query_id):
    resource = get_object_or_404(Resource, pk=resource_id)
    query = get_object_or_404(Query, pk=query_id)
    regions = resource.subscriptions.\
        filter(subscription__query=query).\
        order_by('subscription__region').\
        distinct('subscription__region')
    return render_to_response(
        "monitoringengine_ui/resource_query.html",
        RequestContext(request, {"resource": resource, "regions": regions,
                                 "query": query}))


@login_required
def edit_query(request, resource_id):
    resource = get_object_or_404(Resource, pk=resource_id)
    regions = get_regions_for_resource(resource)
    queries = get_queries_for_resource(resource)
    all_regions = Region.objects.all()
    set_regions = [set_regions for set_regions in all_regions if set_regions not in regions]
    table_data = map(lambda query: (query,ResourceSubscription.objects.filter(subscription__query=query,
                                                                              resource=resource)), queries)

    table_data = map(
        lambda rss: (rss[0], dict(map(
            lambda rs: (rs.subscription.region, rs),
            rss[1]))),
        table_data)

    return render_to_response(
        "monitoringengine_ui/edit_resource.html",
        RequestContext(request, {"resource": resource, "regions": regions,
                                 "queries": queries, "all_regions": all_regions,
                                 "set_regions": set_regions, "table_data": table_data}))

@login_required
def add_query(request, resource_id):
    resource = get_object_or_404(Resource, pk=resource_id)
    querystring = request.POST["querystring"]
    query, created = Query.objects.get_or_create(querystring=querystring)
    if created:
        return HttpResponse(query.id)
    elif ResourceSubscription.objects.filter(subscription__query=query,
                                             datetime_unsubscribed__isnull=True,
                                             resource=resource).exists():
        return HttpResponseBadRequest()
    else:
        return HttpResponse(query.id)


@login_required
def change_search_depth(request, resource_id):
    query_id = request.POST["query_id"]
    region_id = request.POST["region_id"]
    number = int(request.POST["number"])
    search_depths = [50, 100, 200, 350, 500]
    if number < 0 or number > len(search_depths)-1:
        return HttpResponseBadRequest()
    search_depth = search_depths[number]
    resource = get_object_or_404(Resource, pk=resource_id)
    query = get_object_or_404(Query, pk=query_id)
    region = get_object_or_404(Region, pk=region_id)
    rs = ResourceSubscription.objects.get(subscription__query=query,
                                          subscription__region=region,
                                          resource=resource)
    rs.search_depth = search_depth
    rs.save()
    return HttpResponse('%d' % search_depth)

@login_required
def change_subdomain_include(request, resource_id):
        query_id = request.POST["query_id"]
        region_id = request.POST["region_id"]
        number = int(request.POST["number"])
        subdomain_includes = ['strict_domain', 'only_subdomains', 'domain_with_subdomains']
        if number < 0 or number > len(subdomain_includes)-1:
            return HttpResponseBadRequest()
        subdomain_include = subdomain_includes[number]
        resource = get_object_or_404(Resource, pk=resource_id)
        query = get_object_or_404(Query, pk=query_id)
        region = get_object_or_404(Region, pk=region_id)
        rs = ResourceSubscription.objects.get(subscription__query=query,
                                              subscription__region=region,
                                              resource=resource)
        rs.subdomain_include = subdomain_include
        rs.save()
        return HttpResponse('%s' % choose_subdomain_include(subdomain_include))


@login_required
def change_all(request, resource_id):
    resource = get_object_or_404(Resource, pk=resource_id)
    number_search = int(request.POST["number_search"])
    number_subdomain = int(request.POST["number_subdomain"])
    action_type = request.POST["type"]
    search_depths = [50, 100, 200, 350, 500]
    subdomain_includes = ['strict_domain', 'only_subdomains', 'domain_with_subdomains']
    if number_search < 0 or number_search > len(search_depths)-1 or number_subdomain < 0 or number_subdomain > len(subdomain_includes)-1:
        return HttpResponseBadRequest()
    search_depth = search_depths[number_search]
    subdomain_include = subdomain_includes[number_subdomain]
    for q_id, r_id in literal_eval(request.POST['subscriptions']):
        query = get_object_or_404(Query, pk=q_id)
        region = get_object_or_404(Region, pk=r_id)
        if ResourceSubscription.objects.filter(subscription__query=query,
                                               subscription__region=region,
                                               resource=resource).exists():
            rs = ResourceSubscription.objects.get(subscription__query=query,
                                                  subscription__region=region,
                                                  resource=resource)
            if action_type == 'change':
                if rs.datetime_unsubscribed:
                    rs.datetime_unsubscribed = None
                    rs.datetime_subscribed = datetime.datetime.now()
                rs.search_depth = search_depth
                rs.subdomain_include = subdomain_include
                rs.save()
            elif action_type == 'delete':
                rs.datetime_unsubscribed = datetime.datetime.now()
                rs.save()
        elif action_type == 'change':
            subscription, created = Subscription.objects.get_or_create(query=query,
                                                                       region=region)
            ResourceSubscription.objects.create(subscription=subscription,
                                                resource=resource,
                                                search_depth=search_depth,
                                                datetime_subscribed=datetime.datetime.now(),
                                                subdomain_include=subdomain_include)
    return HttpResponseRedirect(reverse("edit_resource", kwargs={"resource_id": resource_id}))


@login_required
def change_region(request, resource_id):
    region_id = request.POST["region_id"]
    query_id = request.POST["query_id"]
    resource = get_object_or_404(Resource, pk=resource_id)
    query = get_object_or_404(Query, pk=query_id)
    region = get_object_or_404(Region, pk=region_id)
    if ResourceSubscription.objects.filter(subscription__query=query,
                                           subscription__region=region,
                                           resource=resource).exists():
        rs = ResourceSubscription.objects.get(subscription__query=query,
                                              subscription__region=region,
                                              resource=resource)

        if rs.datetime_unsubscribed:
            rs.datetime_unsubscribed = None
            rs.datetime_subscribed = datetime.datetime.now()
            rs.save()
        else:
            rs.datetime_unsubscribed = datetime.datetime.now()
            rs.save()
    else:
        subscription, created = Subscription.objects.get_or_create(query=query,
                                                                   region=region)
        rs = ResourceSubscription.objects.create(subscription=subscription,
                                                  resource=resource,
                                                  search_depth=200,
                                                  datetime_subscribed=datetime.datetime.now(),
                                                  subdomain_include='domain_with_subdomains')

    return HttpResponse(rs.search_depth)




@login_required
@any_permission_required("monitoringengine_ui.manager", "monitoringengine_ui.owner")
def delete_query(request, yandex_account_subscription_id):
    if request.is_ajax():
        account = request.user.profile.account
        cursor = connection.cursor()
        cursor.execute("""
            UPDATE yandex_resources_subscriptions SET datetime_unsubscribed = %(datetime_unsubscribed)s,
                search_depth = 0 WHERE account_id = %(account_id)s AND id = %(id)s
        """, {"datetime_unsubscribed": datetime.datetime.now(), "account_id": account.id,
              "id": yandex_account_subscription_id})
        connection.connection.commit()
        return HttpResponse(json.dumps({'deleted': True}),
                            content_type='application/json')
    return HttpResponse(json.dumps({'deleted': False}),
                        content_type='application/json')


def get_regions_for_website_account(cursor, website_id, account):
    cursor.execute("""
                SELECT DISTINCT ON (yandex_regions.id) yandex_regions.id, yandex_regions.name FROM yandex_resources_subscriptions
                    JOIN yandex_subscriptions ON yandex_subscriptions.id=yandex_resources_subscriptions.yandex_subscription_id
                    JOIN yandex_regions ON yandex_regions.id=yandex_subscriptions.yandex_region_id
                WHERE yandex_resources_subscriptions.website_id=%s
                    AND yandex_resources_subscriptions.account_id=%s
                    AND yandex_resources_subscriptions.datetime_unsubscribed  IS NULL
            """, [website_id, account.id, ])
    return cursor.fetchall()


# не нравится жуткое нарушение DRY, как-то пофиксить (черт его знает, как)
def get_regions_for_resource(resource):
    q = (resource
         .subscriptions
         .order_by('subscription__region')
         .distinct('subscription__region'))
    return map(lambda r_s: r_s.subscription.region, q)

def get_regions_for_view(view):
    q = (view
         .entries.filter(subscription__datetime_unsubscribed__isnull=True)
         .order_by('subscription__subscription__region')
         .distinct('subscription__subscription__region'))
    return map(lambda r_s: r_s.subscription.subscription.region, q)

def get_queries_for_resource(resource):
    q = (resource
         .subscriptions
         .order_by('subscription__query')
         .distinct('subscription__query'))
    return map(lambda r_s: r_s.subscription.query, q)


def get_subdomain_include_for_resource(resource):
    q = (resource
         .subscriptions
         .order_by('subdomain_include')
         .distinct('subdomain_include'))
    return map(lambda r_s: r_s.subdomain_include, q)


@login_required
def add_view(request, pk):
    if request.is_ajax() and request.method == 'POST' and 'name' in request.POST:
        resource = get_object_or_404(Resource, pk=pk)
        name = request.POST['name']
        view, created = resource.views.get_or_create(name=name)
        return HttpResponse(reverse("add_entries", kwargs={"pk": view.id}))
    else:
        return HttpResponseBadRequest()


@login_required
def add_entries_to_view(request, pk):
    if request.is_ajax() and request.method == 'POST' and 'entries' in request.POST:
        view = get_object_or_404(View, pk=pk)
        for entry_id in literal_eval(request.POST['entries']):
            entry = get_object_or_404(ViewEntry, pk=entry_id)
            view.entries.get_or_create(subscription=entry.subscription)
        return HttpResponse('True')
    else:
        return HttpResponseBadRequest()

@login_required
def delete_entries(request, pk):
    if request.is_ajax() and request.method == 'POST' and 'entries' in request.POST:
        resource = get_object_or_404(Resource, pk=pk)
        view = get_object_or_404(View, request.GET['view'])
        for entry_id in literal_eval(request.POST['entries']):
            entry = get_object_or_404(ViewEntry, pk=entry_id)
            entry.delete()
        return HttpResponse('True')
    else:
        return HttpResponseBadRequest()


class ResourceView(DetailView):
    template_name = 'monitoringengine_ui/resource.html'
    model = Resource

    def get_context_data(self, **kwargs):
        context = super(ResourceView, self).get_context_data(**kwargs)
        date_until = datetime.date.today() - datetime.timedelta(days=0)
        date_since = date_until - datetime.timedelta(days=92)
        date_mid = date_until - datetime.timedelta(days=14)
        context.update({'regions': get_regions_for_resource(self.object),
                        'default_view_name': u"Представление по умолчанию",
                        'date_since': date_since,
                        'date_until': date_until,
                        'date_mid': date_mid})
        return context

    def post(self, request, **kwargs):
        resource = self.get_object()
        form = ChangeWebsiteNoteForm(request.POST, initial={'note': resource.note})
        if form.is_valid():
            resource.note = form.cleaned_data.get("note")
            resource.save()
            messages.add_message(request, messages.INFO, u"Примечание было изменено")
            return HttpResponseRedirect(resource.get_absolute_url())


@login_required
def region_subscriptions(request, resource_id, region_id):
    resource = get_object_or_404(Resource, pk=resource_id)
    region = get_object_or_404(Region, pk=region_id)
    subscriptions = resource.subscriptions.filter(subscription__region=region)
    return render_to_response(
        "monitoringengine_ui/region_subscriptions.html",
        RequestContext(request, {"subscriptions": subscriptions}))

@login_required
def positions_slider(request, pk, region_id):
    resource = get_object_or_404(Resource, pk=pk)
    view = get_object_or_404(View, pk=request.GET['view'])
    region = get_object_or_404(Region, pk=request.GET['region'])
    date_until = datetime.date.today()
    date_since = date_until - datetime.timedelta(days=90)
    date_mid = datetime.date.today() - datetime.timedelta(days=7)
    return render_to_response("monitoringengine_ui/positions_slider.html",
                              RequestContext(request, {"object": view,
                                                       "region": region,
                                                       "date_until": date_until,
                                                       "date_since": date_since,
                                                       "date_mid": date_mid}))


def get_positions_for_view(view, from_date, to_date, region):
    cursor = connection.cursor()
    cursor.execute("""
        SELECT yandex_accounts_subscriptions.id, MIN(position), MAX(yandex_reports.search_depth), datestamp
        FROM yandex_reports
        JOIN yandex_accounts_subscriptions ON yandex_accounts_subscriptions.id=yandex_account_subscription_id
        WHERE yandex_accounts_subscriptions.id IN
                (SELECT yandex_accounts_subscriptions.id FROM yandex_accounts_subscriptions
                 JOIN monitoringengine_ui_viewentry
                 ON monitoringengine_ui_viewentry.subscription_id=yandex_accounts_subscriptions.id
                 JOIN yandex_subscriptions
                 ON  yandex_accounts_subscriptions.yandex_subscription_id = yandex_subscriptions.id
                 WHERE monitoringengine_ui_viewentry.view_id=%(view_id)s)
        AND datestamp BETWEEN %(from_date)s AND %(to_date)s
        GROUP BY yandex_accounts_subscriptions.id, datestamp
    """, {"view_id": view.id, "from_date": from_date, "to_date": to_date, "region_id": region.id})
    reports = cursor.fetchall()
    positions_by_queries = {}
    # соберем словарь вида {resource_subscription_id: {check: {'position': position, 'max_position': position}}}
    for report in reports:
        resource_subscription_id = report[0]
        position = report[1]
        max_position = report[2]
        check_date = report[3]
        if not resource_subscription_id in positions_by_queries:
            positions_by_queries[resource_subscription_id] = {}
        positions_by_queries[resource_subscription_id].update(
            {check_date: {'position': position, 'max_position': max_position}})

    return positions_by_queries


class UserCreate(CreateView):
    model = User
    fields = ['username']
    template_name = "monitoringengine_ui/add_user.html"
     #def post(self, request, user):
     #   form = ChangeWebsiteNoteForm(request.POST, initial={'note': resource.note})
     #   if form.is_valid():
     #       resource.note = form.cleaned_data.get("note")
     #       resource.save()
     #       messages.add_message(request, messages.INFO, u"Примечание было изменено")
     #       return HttpResponseRedirect(resource.get_absolute_url())


class UserUpdate(UpdateView):
    model = User
    fields = ['username']
    template_name = "monitoringengine_ui/change_client.html"
    pk_url_kwarg = 'user_id'


def positions_with_regions(request, pk):
    resource = get_object_or_404(Resource, pk=pk)
    view = get_object_or_404(View, pk=request.GET["view"])
    regions = get_regions_for_view(view)
    if "since" in request.GET:
        since = int(request.GET["since"])
    else:
        since = 7
    if "until" in request.GET:
        until = int(request.GET["until"])
    else:
        until = 0

    return render_to_response("monitoringengine_ui/positions_regions.html",
                              RequestContext(request, {"object": view, "regions": regions,
                                                       "since": since, "until": until}))


def positions_view(request, pk):
    resource = get_object_or_404(Resource, pk=pk)
    view = get_object_or_404(View, pk=request.GET['view'])
    region = get_object_or_404(Region, pk=request.GET['region'])
    date_until = dateutil.parser.parse(request.GET['until'])
    date_since = dateutil.parser.parse(request.GET['since'])
    checks = [date_since + datetime.timedelta(days=x)  # x+1 -- странный хак, надо разобраться, почему так происходит
              for x in range(0, (date_until - date_since).days + 1)]
    positions = get_positions_for_view(view, checks[0], checks[-1], region)
    print positions

    return render_to_response('monitoringengine_ui/positions.html',
                              RequestContext(request, {'checks': checks,
                                                       'positions': positions,
                                                       'region': region,
                                                       'current_date': datetime.datetime.today(),
                                                       'object': view}))


class ViewView(DetailView):
    template_name = 'monitoringengine_ui/view-ok.html'
    model = View


class PositionsView(ViewView):
    template_name = 'monitoringengine_ui/positions.html'

    @method_decorator(login_required)
    def dispatch(self, request, *args, **kwargs):
        if "since" in request.GET:
            self.since = int(request.GET["since"])
        else:
            self.since = 7
        if "until" in request.GET:
            self.until = int(request.GET["until"])
        else:
            self.until = 0
        self.date_until = datetime.date.today() - datetime.timedelta(days=self.until)
        self.date_since = self.date_until - datetime.timedelta(days=self.since)
        self.date_mid = self.date_until - self.date_since
        self.checks = [self.date_since + datetime.timedelta(days=x)
                       for x in range(0, (self.date_until - self.date_since).days + 1)]
        if "region_id" in kwargs:
            self.region = get_object_or_404(Region, pk=kwargs["region_id"])
            del kwargs["region_id"]
        return super(PositionsView, self).dispatch(request, *args, **kwargs)

    def get_context_data(self, **kwargs):
        context = super(PositionsView, self).get_context_data(**kwargs)

        positions = get_positions_for_view(self.get_object(), self.checks[0], self.checks[-1], self.region)

        context.update({'checks': self.checks,
                        'date_since': self.date_since,
                        'date_until': self.date_until,
                        'date_mid': self.date_mid,
                        'positions': positions,
                        'region': self.region,
                        'current_date': datetime.date.today(),
                        'previous': self.until+7,
                        'next': max(0, self.until-7)})
        return context


@login_required
def view_check_fresh(request, pk):
    resource = get_object_or_404(Resource, pk=pk)
    view = get_object_or_404(View, pk=request.GET['view'])
    if 'timestamp' in request.GET:
        timestamp = datetime.datetime.strptime(request.GET['timestamp'], '%d %m %Y %H:%M:%S.%f')
        if view.last_changed > timestamp:
            return HttpResponse('False')
        else:
            return HttpResponse('True')
    else:
        raise Http404


@login_required
def save_view(request, pk):
        resource = get_object_or_404(Resource, pk=pk)
        view = get_object_or_404(View, request.GET['view'])
        if request.method == 'POST' and 'sorting_order' in request.POST:
            sorting_order = literal_eval(request.POST['sorting_order'])
            for order, entry_id in enumerate(sorting_order):
                entry = view.entries.get(pk=entry_id)
                entry.sorting_order = order
                entry.save()
            view.last_changed = datetime.datetime.now()
            view.save()
            return HttpResponse("")
        else:
            raise Http404



@login_required
def view_sync(request, pk):
    resource = get_object_or_404(Resource, pk=pk)
    view = get_object_or_404(View, request.GET['view'])
    return HttpResponse(view.last_changed.strftime('%d %m %Y %H:%M:%S.%f'))


@login_required
def manage_perm(request, action, model, pk, username, perm_type):
    obj = get_object_or_404(get_model('monitoringengine_ui', model), pk=pk)
    if has_perm('manage')(request.user, obj):
        redirect = '/'
        if 'redirect' in request.GET:
            redirect = request.GET['redirect']
        perm = obj.perms.get(perm_type=perm_type).permission
        user = User.objects.get(username=username)
        if action == 'remove':
            user.user_permissions.remove(perm)
            return HttpResponseRedirect(redirect)
        elif action == 'add':
            user.user_permissions.add(perm)
            return HttpResponseRedirect(redirect)
    else:
        raise Http404


@login_required
def add_user_to_object(request, model, pk):
    obj = get_object_or_404(get_model('monitoringengine_ui', model), pk=pk)
    if has_perm('manage')(request.user, obj) and 'email' in request.GET and request.GET['email']:
        redirect = '/'
        if 'redirect' in request.GET:
            redirect = request.GET['redirect']
        user = get_object_or_404(User, email=request.GET['email'])
        perm = obj.perms.get(perm_type='read').permission
        user.user_permissions.add(perm)
        return HttpResponseRedirect(redirect)
    raise Http404


class SubscriptionCreate(TemplateView):
    template_name = "monitoringengine_ui/add_subscription.html"
    form_class = AddSubscriptionForm

    def dispatch(self, request, pk):
        resource = get_object_or_404(Resource, id=pk)
        return super(SubscriptionCreate, self).dispatch(request, resource=resource)

    def get_context_data(self, **kwargs):
        context = super(SubscriptionCreate, self).get_context_data(**kwargs)
        context.update({'form': AddSubscriptionForm()})
        return context

    def post(self, request, resource):
        form = self.form_class(request.POST)
        if form.is_valid():
            querystring = form.cleaned_data['querystring']
            query, q_created = Query.objects.get_or_create(querystring=querystring)
            for region_id in form.cleaned_data['regions']:
                region = get_object_or_404(Region, pk=region_id)
                subscription, s_created = Subscription.objects.get_or_create(query=query, region=region)
                resource_subscription = get_object_or_None(
                    ResourceSubscription,
                    resource=resource,
                    subscription=subscription)
                if not resource_subscription:
                    resource_subscription = ResourceSubscription.objects.create(
                        resource=resource,
                        subscription=subscription,
                        search_depth=form.cleaned_data['search_depth'],
                        datetime_subscribed = datetime.datetime.now(),
                        subdomain_include = form.cleaned_data['subdomain_include'])
                    #resource_subscription.search_depth = form.cleaned_data['search_depth']
                    #resource_subscription.datetime_subscribed = datetime.datetime.now()
                    #resource_subscription.subdomain_include = form.cleaned_data['subdomain_include']
                    #resource_subscription.save()
        return HttpResponseRedirect(resource.get_absolute_url())


class QueryWizard(FormWizard):
    def parse_params(self, request, pk):
        resource = get_object_or_404(Resource, pk=pk)
        cursor = connection.cursor()
        cursor.execute("""SELECT hostname FROM Websites WHERE id = %s""", [resource.website.id, ])
        site_url = cursor.fetchone()
        if not site_url:
            raise Http404
        else:
            self.site_url = site_url[0]
        self.resource_id = int(pk)
        self.extra_context.update({"site_url": self.site_url, "resource_id": pk})

    def process_step(self, request, form, step):
        if step == 0 and hasattr(form, 'cleaned_data'):
            search_engines = form.cleaned_data.get("search_engines")
            if "yandex" in search_engines and AddYandexQueryForm not in self.form_list:
                self.form_list.append(AddYandexQueryForm)

    def __get_form_from_list__(self, form_list, form_class):
        for form in form_list:
            if isinstance(form, form_class):
                return form
        return None

    def done(self, request, form_list):
        account = request.user.profile.account
        cursor = connection.cursor()
        form = form_list[0]
        querystring = form.cleaned_data.get("querystring")
        subdomain_include = form.cleaned_data.get("subdomain_include")
        search_engines = form.cleaned_data.get("search_engines")
        if "yandex" in search_engines:
            yandex_form = self.__get_form_from_list__(form_list, AddYandexQueryForm)
            yandex_regions = yandex_form.cleaned_data.get("regions")
        else:
            yandex_regions = []
            # Для каждой поисковой системы определяем количество запросов(пока только yandex)
        queries_number = len(yandex_regions)
        account_queries_number = account_subscriptions_number(cursor, account.id)
        cursor.execute("""SELECT max_subscriptions_number FROM accounts WHERE id=%s""", [account.id])
        max_account_queries_number = cursor.fetchone()[0]
        if not max_account_queries_number or queries_number <= max_account_queries_number - account_queries_number:
            if yandex_regions:
                # получаем или создаем запрос
                cursor.execute("""SELECT id FROM queries WHERE querystring = %s""", [querystring])
                query_id = cursor.fetchone()
                if not query_id:
                    cursor.execute("""INSERT INTO queries (querystring) VALUES (%s)""", [querystring])
                    cursor.execute("""SELECT CURRVAL(pg_get_serial_sequence('queries','id'))""")
                    query_id = cursor.fetchone()[0]
                else:
                    query_id = query_id[0]
                connection.connection.commit()
                # создаем подписки
                cursor.executemany("""
                    INSERT INTO yandex_subscriptions (yandex_region_id, query_id)
                        SELECT yandex_region_id, query_id FROM (VALUES (%s, %s)) AS
                            new_yandex_subscriptions (yandex_region_id, query_id)
                        WHERE NOT EXISTS (SELECT * FROM yandex_subscriptions WHERE
                            yandex_subscriptions.query_id=new_yandex_subscriptions.query_id AND
                            yandex_subscriptions.yandex_region_id=new_yandex_subscriptions.yandex_region_id)
                    """, [[int(region), query_id] for region in yandex_regions])
                connection.connection.commit()
                # связываем аккаунт с подписками
                cursor.execute("""
                    INSERT INTO yandex_resources_subscriptions
                        (account_id, resource_id, subdomain_include, yandex_subscription_id, datetime_subscribed, last_changed)
                    SELECT * FROM (
                        SELECT %(account_id)s, %(resource_id)s, %(subdomain_include)s::subdomain_include_type,
                                id, %(datetime)s, %(datetime)s FROM yandex_subscriptions WHERE
                                query_id = %(query_id)s AND yandex_region_id = ANY(%(yandex_region_ids)s)
                        ) AS new_yandex_resources_subscriptions(
                            account_id, resource_id, subdomain_include, yandex_subscription_id, datetime_unsubscribed)
                        WHERE NOT EXISTS (SELECT * FROM yandex_resources_subscriptions WHERE
                            yandex_resources_subscriptions.account_id=new_yandex_resources_subscriptions.account_id AND
                            yandex_resources_subscriptions.website_id=new_yandex_resources_subscriptions.website_id AND
                            yandex_resources_subscriptions.yandex_subscription_id=new_yandex_resources_subscriptions.yandex_subscription_id AND
                            yandex_resources_subscriptions.datetime_unsubscribed IS NULL AND
                            yandex_resources_subscriptions.subdomain_include=%(subdomain_include)s
                        )
                    """, {'account_id': account.id, 'resource_id': self.resource_id,
                          'subdomain_include': subdomain_include, 'datetime': datetime.datetime.now(),
                          'query_id': query_id, 'yandex_region_ids': [int(region) for region in yandex_regions]})
            connection.connection.commit()
            messages.add_message(request, messages.ERROR, u"Запрос '%s' был добавлен" % querystring)
        else:
            messages.add_message(request, messages.INFO, u"Вы можете добавить не более %s запросов" %
                                                         max_account_queries_number - account_queries_number)

        return HttpResponseRedirect(reverse("website", kwargs={"resource_id": self.resource_id}))


query_wizard = login_required(any_permission_required("monitoringengine_ui.manager", "monitoringengine_ui.owner")(
    QueryWizard([AddQueryForm])))


def search_results_to_ods(checks, view, search_engine='Yandex'):
    ods = ODS()
    current_date = datetime.date.today()
    # sheet title
    sheet = ods.content.getSheet(0)
    sheet.getCell(0, 0).stringValue(u"{hostname} {search_engine}-{region}".format(
        hostname=view.resource.website.hostname,
        search_engine=search_engine, region=view.name))
    sheet.getCell(0, 1).stringValue(u"Запрос")
    sheet.getCell(1, 1).stringValue(u"Частотность")
    for i, check_date in enumerate(checks, start=2):
        sheet.getCell(i, 1).stringValue(check_date.strftime("%Y-%m-%d"))
        for j, entry in enumerate(view.entries.all(), start=2):
        #            первый проход
            if i == 2:
                sheet.getCell(0, j).stringValue(entry.subscription.subscription.__unicode__())
                if entry.subscription.subscription.quantities.exists():
                    sheet.getCell(1, j).stringValue(entry.subscription.subscription.quantities.latest().quantity)
                else:
                    sheet.getCell(1, j).stringValue("-")
            q = entry.subscription.reports.filter(datestamp=check_date)
            if q.exists():
                if q[0].position >= 0:
                    cell_value = q[0].position
                else:
                    cell_value = u"Не попал в %s" % entry.subscription.search_depth
            else:
                if check_date == current_date:
                    cell_value = u'сбор данных'
                else:
                    cell_value = u"N/A"
                    sheet.getCell(i, j).setFontColor('#808080')
            sheet.getCell(i, j).stringValue(cell_value)
    response = HttpResponse(mimetype=ods.mimetype.toString())
    response['Content-Disposition'] = 'attachment; filename="report.ods"'
    ods.save(response)
    return response


@login_required
def export(request, pk):
    view = get_object_or_404(View, pk=pk)
    date_until = datetime.date.today()
    date_since = date_until - datetime.timedelta(days=7)
    if ('date_since' in request.GET) and (request.GET['date_since'] != 'undefined'):
        date_since = dateutil.parser.parse(request.GET['date_since'])
        date_until = dateutil.parser.parse(request.GET['date_until'])
        checks = [date_since + datetime.timedelta(days=x+1)
                  for x in range(0, (date_until - date_since).days + 1)]
    return search_results_to_ods(checks, view)


def positions_for_website(request, website_id):
    u"""
    Возвращаются позиции для запросов в определенный промежуток времени
    для ajax запроса возвращается html, для POST запроса при action==save возвращается ods
    """
    account = request.user.profile.account
    cursor = connection.cursor()
    regions = get_regions_for_website_account(cursor, website_id, account)
    current_date = datetime.date.today()
    if request.method == "POST":
        form = WebsiteSearchResultsForm(data=request.POST, regions=regions)
        if form.is_valid():
            cleaned_data = form.cleaned_data
            date_since = cleaned_data.get("date_since")
            date_until = cleaned_data.get("date_until")
            region = cleaned_data.get("region")
            search_engine = cleaned_data.get("search_engine")
            subdomain_include = cleaned_data.get("subdomain_include")
            cursor.execute("""SELECT hostname FROM websites WHERE id=%s""", [website_id])
            hostname = cursor.fetchone()[0]
            hostname_regexp = r'^(.*\.)?{0}$'.format(re.escape(hostname))
            sorting_order = "yandex_resources_subscriptions.sorting_order"
            asc = "ASC"
            if "sorting_by" in request.POST:
                if request.POST["sorting_by"] == "query":
                    sorting_order = "queries.querystring"
                elif request.POST["sorting_by"] == "quantity":
                    sorting_order = "quantity.common_quantity"
                if request.POST["asc"] == "asc":
                    asc = "ASC"
                elif request.POST["asc"] == "desc":
                    asc = "DESC"
            cursor.execute("""SELECT yandex_subscriptions.id, queries.id, queries.querystring, quantity.common_quantity,
                        yandex_resources_subscriptions.subdomain_include, yandex_resources_subscriptions.id, 
                        yandex_resources_subscriptions.sorting_order, yandex_resources_subscriptions.last_changed FROM yandex_resources_subscriptions 
                    JOIN yandex_subscriptions ON yandex_subscriptions.id=yandex_resources_subscriptions.yandex_subscription_id
                    JOIN queries ON queries.id=yandex_subscriptions.query_id
                    LEFT JOIN (SELECT * from yandex_wordstat where
                        (yandex_wordstat.timestamp, yandex_wordstat.yandex_subscription_id) IN
                            (select max(yandex_wordstat.timestamp), yandex_wordstat.yandex_subscription_id from yandex_wordstat
                                group by yandex_wordstat.yandex_subscription_id)) quantity
                        ON quantity.yandex_subscription_id=yandex_subscriptions.id
                WHERE yandex_resources_subscriptions.website_id=%(website_id)s
                    AND yandex_resources_subscriptions.account_id=%(account_id)s
                    AND yandex_resources_subscriptions.subdomain_include=%(subdomain_include)s
                    AND yandex_subscriptions.yandex_region_id=%(yandex_region_id)s
                    AND yandex_resources_subscriptions.datetime_unsubscribed  IS NULL
                ORDER BY {order} {asc}, quantity.common_quantity DESC NULLS LAST, queries.querystring
            """.format(order=sorting_order, asc=asc),
                           {'website_id': website_id, 'account_id': account.id, 'yandex_region_id': region,
                            'subdomain_include': subdomain_include})
            queries = cursor.fetchall()

            checks = [date_since + datetime.timedelta(days=x) for x in range(0, (date_until - date_since).days + 1)]
            #        получаем поисковые результаты для данного сайта и запроса
            cursor.execute("""
                SELECT yandex_subscription_id, MIN(position), MAX(yandex_reports.search_depth), datestamp FROM yandex_reports
                JOIN yandex_resources_subscriptions ON yandex_resources_subscriptions.id=yandex_account_subscription_id
                WHERE yandex_resources_subscriptions.yandex_subscription_id IN
                        (SELECT id FROM yandex_subscriptions WHERE yandex_region_id=%(region_id)s) AND
                    website_id IN (SELECT id FROM websites WHERE websites.hostname ~ %(hostname_regexp)s) AND
                    account_id=%(account_id)s AND datestamp BETWEEN %(from_date)s AND %(to_date)s
                GROUP BY yandex_subscription_id, datestamp
            """, {"region_id": region, "hostname_regexp": hostname_regexp, "account_id": account.id,
                  "from_date": checks[0], "to_date": checks[-1]})
            reports = cursor.fetchall()
            positions_by_queries = {}
            # соберем словарь вида {yandex_subscription_id: {check_id: {position: position, max_position:position}}}
            for report in reports:
                yandex_subscription_id = report[0]
                position = report[1]
                max_position = report[2]
                check_date = report[3]
                if not yandex_subscription_id in positions_by_queries:
                    positions_by_queries[yandex_subscription_id] = {
                        check_date: {"position": position, "max_position": max_position}}
                else:
                    positions_by_queries[yandex_subscription_id].update(
                        {check_date: {"position": position, "max_position": max_position}})
            context = {'checks': checks, 'queries': queries, "website_id": website_id,
                       'positions_by_queries': positions_by_queries, 'current_date': current_date}
            # в зависимости от типа запроса различный ответ
            if request.is_ajax():
                if request.POST["type"] == "update_table":
                    return render_to_response(
                        "monitoringengine_ui/positions_for_website.html",
                        RequestContext(request, context))
                elif request.POST["type"] == "is_fresh":
                    timestamps = filter(lambda s: s != '', request.POST["last_changed"].split(";"))
                    last_changed = map(lambda query: query[7], queries)
                    timestamps = map(lambda s: datetime.datetime.strptime(s, '%d %m %Y %H:%M:%S.%f'), timestamps)
                    if timestamps >= last_changed:
                        return HttpResponse("True")
                    else:
                        return HttpResponse("False")
                elif request.POST["type"] == "save":
                    sorting_order = map(int, filter(lambda s: s != '', request.POST["sorting_order"].split(";")))
                    cursor.executemany("""
                        UPDATE yandex_resources_subscriptions SET sorting_order = %(i)s, last_changed = now()  WHERE id = %(a)s 
                        """, [{'i': i, 'a': a} for i, a in enumerate(sorting_order, start=1)])
                    connection.connection.commit()
                    return HttpResponse("")
                elif request.POST["type"] == "get_timestamps":
                    last_changed = map(lambda query: query[7].strftime('%d %m %Y %H:%M:%S.%f'), queries)
                    return HttpResponse(last_changed[0])

            # экспорт в ODS
            elif request.POST["type"] == "save":
                context.update({
                    "search_engine": dict(form.fields["search_engine"].choices).get(search_engine),
                    "region": dict(form.fields["region"].choices).get(int(region)),
                    'subdomain_include': subdomain_include, 'hostname': hostname,
                })
                return search_results_to_ods(**context)
        else:
            return HttpResponseBadRequest(form.errors.as_ul())
    return HttpResponseBadRequest()
