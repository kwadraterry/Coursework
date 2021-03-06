# -*- coding: utf-8 -*- 
from django.contrib import messages
from django.contrib.auth import get_backends, login
from django.contrib.auth.forms import SetPasswordForm
from django.core.urlresolvers import reverse
from django.http import HttpResponseRedirect
from django.shortcuts import get_object_or_404
from django.views.generic.base import TemplateView
from monitoringengine_ui.authorisation.forms import EmailResetForm,ChangeUsernameForm
from monitoringengine_ui.authorisation.models import VerificationKey
from monitoringengine_ui.authorisation.utils import get_user_by_email


class EmailVerification(TemplateView):
    u"""Изменение заявки пользователем"""
    template_name = 'authorisation/email_verification.html'

    def get(self, request, key):
        verification_key_object = get_object_or_404(VerificationKey, key=key)
        if not verification_key_object.is_valid:
            message = u'Ссылка недействительна, попробуйте получить новую.'
            return self.render_to_response({'message': message})
        user = verification_key_object.user
        if not user.is_active:
            message = u'Пользователь был заблокирован, подтверждение почты невозможно.'
            return self.render_to_response({'message': message})
        if get_user_by_email(user.email):
            message = u'Адрес, который вы пытаетесь подтвердить уже зарегистрирован и подтвержден.'
            return self.render_to_response({'message': message})
        else:
            verification_key_object.unused = False
            verification_key_object.save()
            profile = user.get_profile()
            profile.email_verified = True
            profile.save()
            message = u'Адрес электронной почты %s подтвержден!' % user.email
            messages.info(request, message)

            if user.is_active:
                backend = get_backends()[1]
                user.backend = "%s.%s" % (backend.__module__, backend.__class__.__name__)
                login(request, user)

            return HttpResponseRedirect(reverse('frontpage'))


class UserInfo(TemplateView):
    template_name = "authorisation/user_info.html"


    def get(self, request):
        form = ChangeUsernameForm()
        return self.render_to_response({'form': form, 'messages': messages.get_messages(request)})

    def post(self, request):
        form = ChangeUsernameForm(request.POST)
        if form.is_valid():
            username = form.cleaned_data['username']
            user = request.user
            previous_name = user.username
            user.username = username
            user.save()
            messages.success(request, u'''Имя пользователя успешно изменено с %s на %s''' %
                                      (previous_name, username))
            return HttpResponseRedirect(reverse('frontpage'))
        return self.render_to_response({'form': form, 'messages': messages.get_messages(request)})

class ResetPasswordRequest(TemplateView):
    template_name = 'authorisation/reset_password_request.html'

    def get(self, request):
        form = EmailResetForm()
        return self.render_to_response({'form': form})

    def post(self, request):
        form = EmailResetForm(request.POST)
        if form.is_valid():
            user = form.save()
            messages.info(request, u'''
                 На указанный в профиле адрес электронной почты(%s)
                 выслано письмо с инструкцией по восстановлению пароля.
            ''' % user.email)
            return HttpResponseRedirect(reverse('frontpage'))
        return self.render_to_response({'form': form})


class ResetPassword(TemplateView):
    template_name = 'authorisation/reset_password.html'

    def dispatch(self, request, key):
        verification_key_object = get_object_or_404(VerificationKey, key=key)
        if not verification_key_object.is_valid:
            return {'message': u'Данная ссылка уже использовалась, попробуйте получить новую.'}
        return TemplateView.dispatch(self, request,
            verification_key_object=verification_key_object)

    def get(self, request, verification_key_object):
        form = SetPasswordForm(verification_key_object.user)
        return self.render_to_response({'form': form,
            'username':verification_key_object.user.email})

    def post(self, request, verification_key_object):
        user = verification_key_object.user
        form = SetPasswordForm(user, request.POST)
        if form.is_valid():
            form.save()
            verification_key_object.valid = False
            verification_key_object.save()
            if user.is_active:
                backend = get_backends()[1]
                user.backend = "%s.%s" % (backend.__module__, backend.__class__.__name__)
                login(request, user)
            messages.info(request,
                u"Пароль пользователя успешно изменён." % user)
            return HttpResponseRedirect(reverse('frontpage'))
        return self.render_to_response({'form': form, 'username': user.email})
