# -*- coding: utf-8 -*-
from django.conf import settings
from django.shortcuts import render_to_response
from django.template.context import RequestContext
from django.http import Http404
import os
from monitoringengine_ui.captcha_solver.forms import CaptchaForm


def captcha_solver(request, captcha_type, captcha_id):
    if captcha_type == "yandex":
        captcha_url = settings.YANDEX_CAPTCHA_URL + "{0}.gif".format(captcha_id)
        captcha_dir = os.path.join(settings.YANDEX_CAPTCHA_DIR)
    elif captcha_type == "google":
        captcha_url = settings.GOOGLE_CAPTCHA_URL + "{0}.jpg".format(captcha_id)
        captcha_dir = os.path.join(settings.GOOGLE_CAPTCHA_DIR)
    elif captcha_type == "wordstat":
        captcha_url = settings.WORDSTAT_CAPTCHA_URL + "{0}.gif".format(captcha_id)
        captcha_dir = os.path.join(settings.WORDSTAT_CAPTCHA_DIR)
    else:
        raise Http404
    if request.method == "POST":
        form = CaptchaForm(request.POST)
        if form.is_valid():
            symbols = form.cleaned_data.get("symbols")
            captcha_text_file = open(os.path.join(captcha_dir, "{0}.txt".format(captcha_id)), 'w')
            captcha_text_file.write(symbols)
            captcha_text_file.close()
            return render_to_response("captcha_solver/thanks.html", RequestContext(request, {}))
    else:
        form = CaptchaForm()
    return render_to_response("captcha_solver/captcha.html", RequestContext(request, {
        "form": form, "captcha_url": captcha_url}))