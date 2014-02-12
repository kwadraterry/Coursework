# -*- coding: utf-8 -*-
import uuid
from django import forms
from django.contrib.auth.models import User
from django.forms import CheckboxSelectMultiple
from django.db import connection
from urlparse import urlparse
from monitoringengine_ui.authorisation.models import VerificationKey

cursor = connection.cursor()


subdomain_include_choices = (('strict_domain', u'Точный адрес'),
                             ('only_subdomains', u'Только поддомены'),
                             ('domain_with_subdomains', u'Адрес и поддомены'))


class SiteAddForm(forms.Form):
    hostname = forms.URLField(label=u"Хост сайта", max_length=255)

    def clean_hostname(self):
        url = self.cleaned_data.get("hostname")
        hostname = urlparse(url).hostname
        if not hostname:
            raise forms.ValidationError(u"Неверное имя хоста")
        else:
            return hostname.encode("idna")


class ChangeWebsiteNoteForm(forms.Form):
    note = forms.CharField(label=u"Примечание", max_length=255, required=False,
                           widget=forms.TextInput(attrs={'class': "form-control"}))


#TODO: убрать
class AddUserForm(forms.ModelForm):
    type = forms.ChoiceField(label=u"Роль",
                             choices=(
                                 ("owner", u"Владелец"),
                                 ("manager", u"Менеджер"),
                                 ("client", u"Клиент"),
                             ))

    class Meta:
        model = User
        fields = ("email",)

    def clean_email(self):
        email = self.cleaned_data.get("email")
        if User.objects.filter(profile__email_verified=True, email=email, is_active=True).exists():
            raise forms.ValidationError(u"Такой e-mail уже зарегистрирован")
        return email

    def clean(self):
        return self.cleaned_data

    def save(self, commit=True):
        user = super(AddUserForm, self).save(commit=False)
        username = unicode(uuid.uuid4())
        username = username.replace('-', '')[:30]
        user.username = username
        temp_password = User.objects.make_random_password()
        user.set_password(temp_password)
        user.save()
        verification_key_object = VerificationKey.objects.create_key(user)
        verification_key_object.send_email_verification(password=temp_password)
        return user


class SubdomainIncludeChoiceForm(forms.Form):
    subdomain_include = forms.ChoiceField(choices=subdomain_include_choices, initial="domain_with_subdomains")


class AddQueryForm(forms.Form):
    querystring = forms.CharField(label=u"Поисковый запрос")
    subdomain_include = forms.ChoiceField(label=u"Поддомены для сайта", choices=subdomain_include_choices,
                                          initial="domain_with_subdomains")
    search_engines = forms.MultipleChoiceField(
        label=u"Поисковая система", choices=(("yandex", u"Яндекс"),),
        widget=CheckboxSelectMultiple,
    )


class AddSubscriptionForm(forms.Form):
    querystring = forms.CharField(label=u"")
    subdomain_include = forms.ChoiceField(label=u"Поддомены для сайта", choices=subdomain_include_choices,
                                          initial="domain_with_subdomains")
    search_depth = forms.IntegerField(label=u"Глубина поиска")
    cursor.execute("""SELECT id, name FROM yandex_regions""")
    regions = forms.MultipleChoiceField(
        label=u"Регионы Яндекса",
        choices=[[region[0], region[1]] for region in cursor.fetchall()],
        widget=CheckboxSelectMultiple)


class AddYandexQueryForm(forms.Form):
    cursor.execute("""SELECT id, name FROM yandex_regions""")
    regions = forms.MultipleChoiceField(
        label=u"Регионы Яндекса",
        choices=[[region[0], region[1]] for region in cursor.fetchall()],
        widget=CheckboxSelectMultiple)


class WebsiteSearchResultsForm(forms.Form):
    date_since = forms.DateField(label=u"Начало временного диапазона")
    date_until = forms.DateField(label=u"Конец временного диапазона")
    region = forms.ChoiceField(label=u'Регион поиска',)
    search_engine = forms.ChoiceField(
        label=u"Поисковая система", choices=(("yandex", u"Яндекс"),))
    subdomain_include = forms.ChoiceField(label=u"Адрес сайта", choices=subdomain_include_choices,
                                          initial="domain_with_subdomains")

    def __init__(self, regions, subdomain_include=None, *args, **kwargs):
        self.base_fields["region"].choices = enumerate(regions)
        if subdomain_include is not None:
            subdomain_include_choices_dict = dict(subdomain_include_choices)
            self.base_fields["subdomain_include"].choices = [
                (el, subdomain_include_choices_dict[el]) for el in subdomain_include]
            if self.base_fields["subdomain_include"].choices:
                self.base_fields["subdomain_include"].initial = self.base_fields["subdomain_include"].choices[0][0]
        super(WebsiteSearchResultsForm, self).__init__(*args, **kwargs)
