# -*- coding: utf-8 -*-
import os
PROJECT_ROOT = os.path.dirname(os.path.dirname(__file__))

gettext_noop = lambda s: s

ADMINS = (
    ('ekaterina.nepovinnykh', 'ekaterina.nepovinnykh@redsolution.ru'),
    ('igor.sukhinsky', 'igor.sukhinsky@redsolution.ru'),
)

MANAGERS = ADMINS

EMAIL_SUBJECT_PREFIX = '(Monitoringengine) '

DEFAULT_FROM_EMAIL = 'no-reply@redsolution.ru'
SERVER_EMAIL = 'monitoringengine'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'monitoringengine',
        'USER': '',
        'PASSWORD': '',
        'HOST': '',
        'PORT': 5432,
    }
}

TIME_ZONE = None

USE_L10N = True
LANGUAGE_CODE = 'ru'

USE_THOUSAND_SEPARATOR = True
THOUSAND_SEPARATOR = ' '

SITE_ID = 1

MEDIA_ROOT = os.path.join(PROJECT_ROOT, 'media')
STATIC_ROOT = os.path.join(PROJECT_ROOT, 'static')
UPLOAD_DIR = 'upload'

MEDIA_URL = '/media/'
STATIC_URL = '/static/'
UPLOAD_URL = MEDIA_URL + UPLOAD_DIR

ADMIN_MEDIA_PREFIX = STATIC_URL + 'admin/'

SECRET_KEY = 'f65gz1!9=(=sgx7@^vho7glgehjcfsvdav9kb7hu&fbh*gwc!3'

AUTH_PROFILE_MODULE = "monitoringengine_ui.Profile"

MIDDLEWARE_CLASSES = [
    'social_auth.middleware.SocialAuthExceptionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.doc.XViewMiddleware',
    'django.middleware.locale.LocaleMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    # 'django.contrib.redirects.middleware.RedirectFallbackMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
]

ROOT_URLCONF = 'monitoringengine_ui.urls'
EMAIL_HOST = 'localhost'
EMAIL_PORT = 25

TEMPLATE_LOADERS = [
    'django.template.loaders.filesystem.Loader',
    'django.template.loaders.app_directories.Loader',
]

TEMPLATE_DIRS = [
    os.path.join(PROJECT_ROOT, 'templates'),
]

FIXTURE_DIRS = [
    os.path.join(PROJECT_ROOT, 'fixtures'),
]

TEMPLATE_CONTEXT_PROCESSORS = [
    'django.contrib.auth.context_processors.auth',
    'django.core.context_processors.i18n',
    'django.core.context_processors.debug',
    'django.core.context_processors.media',
    'django.core.context_processors.request',
    'django.core.context_processors.static',
]

INSTALLED_APPS = [
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.admin',
    'django.contrib.sites',
    'django.contrib.sitemaps',
    'django.contrib.redirects',
    'django.contrib.staticfiles',
    'monitoringengine_ui',
    'monitoringengine_ui.captcha_solver',
    'monitoringengine_ui.authorisation',
    "zenforms",
    'social_auth',
]

AUTHENTICATION_BACKENDS = (
    'monitoringengine_ui.authorisation.backends.EmailAuthBackend',
    'social_auth.backends.twitter.TwitterBackend',
    'social_auth.backends.facebook.FacebookBackend',
    'social_auth.backends.google.GoogleBackend',
    'social_auth.backends.contrib.vkontakte.VKontakteBackend',
    'social_auth.backends.contrib.odnoklassniki.OdnoklassnikiBackend',
    'django.contrib.auth.backends.ModelBackend',
)

# Server settings
FORCE_SCRIPT_NAME = ''

CACHE_BACKEND = 'locmem:///?max_entries=5000'

#------------------------------------------------------------------------------
#                       Custom applicaitons settings
#------------------------------------------------------------------------------

# ---- Static files ----
STATICFILES_DIRS = (
    MEDIA_ROOT,
)

STATICFILES_FINDERS = (
    'django.contrib.staticfiles.finders.FileSystemFinder',
    'django.contrib.staticfiles.finders.AppDirectoriesFinder',
    )

YANDEX_CAPTCHA_URL = '/media/upload/captcha/yandex/'
YANDEX_CAPTCHA_DIR = os.path.join(MEDIA_ROOT, "/upload/captcha/yandex/")
WORDSTAT_CAPTCHA_URL = '/media/upload/captcha/wordstat/'
WORDSTAT_CAPTCHA_DIR = os.path.join(MEDIA_ROOT, "/upload/captcha/wordstat/")
GOOGLE_CAPTCHA_URL = '/media/img/captcha/google/'
GOOGLE_CAPTCHA_DIR = os.path.join(MEDIA_ROOT, os.path.normpath(GOOGLE_CAPTCHA_URL))

LOGIN_URL = "/auth/login/"
LOGIN_REDIRECT_URL = "/auth/user_info/"

# django-social-auth
SOCIAL_AUTH_CREATE_USERS = False
SOCIAL_AUTH_PROTECTED_USER_FIELDS = ['email',]

SOCIAL_AUTH_PIPELINE = (
    'social_auth.backends.pipeline.social.social_auth_user',
    #'social_auth.backends.pipeline.associate.associate_by_email',
    'social_auth.backends.pipeline.user.get_username',
    #'social_auth.backends.pipeline.user.create_user',
    'social_auth.backends.pipeline.social.associate_user',
    'social_auth.backends.pipeline.social.load_extra_data',
    'social_auth.backends.pipeline.user.update_user_details'
)

TWITTER_CONSUMER_KEY = 'v89gNmXtjbTgU6poMhXC0g'
TWITTER_CONSUMER_SECRET = 'eqyBGIeLlSXtxwSrrNYn37jhM3fK7QSryoO0P10'

FACEBOOK_APP_ID = '630568246959473'
FACEBOOK_API_SECRET = '2a7c9af13ef1b3223da1f451a271d316'