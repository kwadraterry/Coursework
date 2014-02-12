# -*- coding: utf-8 -*- 
from django.conf.urls.defaults import patterns, url
from forms import LoginForm
# from monitoringengine_ui.authorisation.views import signup
from monitoringengine_ui.authorisation.views import EmailVerification, ResetPasswordRequest, ResetPassword, UserInfo

urlpatterns = patterns('django.contrib.auth.views',
    url(r'^login/$', 'login',
            {'template_name': 'authorisation/login.html', 'authentication_form': LoginForm},
        name='login'),
    url(r'^passwd/$', 'password_change',
            {'template_name': 'authorisation/passwd.html'}, name='passwd'),
    url(r'^passwd/done/$', 'password_change_done',
            {'template_name': 'authorisation/passwd_done.html'}, name='passwd_done'),
    url(r'^logout/$', 'logout', {'next_page': '/', }, name="logout"),

)

urlpatterns += patterns('',
    # url(r'^signup/$', Signup.as_view(), name="signup"),
    url(r'^user_info/$', UserInfo.as_view(), name="user_info"),
    url(r'^email_verification/(?P<key>\w{40})/$',
        EmailVerification.as_view(), name='email_verification'),
    url(r'^reset_password_request/$',
        ResetPasswordRequest.as_view(), name='reset_password_request'),
    url(r'^reset_password/(?P<key>\w{40})/$',
        ResetPassword.as_view(), name='reset_password'),
)
