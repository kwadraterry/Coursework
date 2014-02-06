# -*- coding: utf-8 -*-
import uuid
from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.sites.models import Site


def get_user_by_email(email):
    # если e-mail уже занят(подтвержден), то возвращает пользователя,
    # иначе None
    if email:
        try:
            user = User.objects.get(email=email, is_active=True)
        except User.DoesNotExist:
            return None
        else:
            return user
    return None


def scheme_and_domain():
    """Returns dictionary with URL scheme and site domain"""
    return {
        'scheme': getattr(settings, "DEFAULT_HTTP_PROTOCOL", "http"),
        'domain': Site.objects.get_current(),
        }


def get_unique_username():
    """Returns uuid generated 30-character string"""
    s = unicode(uuid.uuid4())
    s = s.replace('-', '')[:30]
    return s