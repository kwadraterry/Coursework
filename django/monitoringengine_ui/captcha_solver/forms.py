# -*- coding: utf-8 -*-
from django import forms


class CaptchaForm(forms.Form):
    symbols = forms.CharField(label=u'Символы с картинки')