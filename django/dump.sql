--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: monitoringengine; Type: DATABASE; Schema: -; Owner: monitoringengine
--

CREATE DATABASE monitoringengine WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'ru_RU.UTF-8' LC_CTYPE = 'ru_RU.UTF-8';


ALTER DATABASE monitoringengine OWNER TO monitoringengine;

\connect monitoringengine

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: subdomain_include_type; Type: TYPE; Schema: public; Owner: monitoringengine
--

CREATE TYPE subdomain_include_type AS ENUM (
    'strict_domain',
    'only_subdomains',
    'domain_with_subdomains'
);


ALTER TYPE public.subdomain_include_type OWNER TO monitoringengine;

--
-- Name: update_search_depth(); Type: FUNCTION; Schema: public; Owner: monitoringengine
--

CREATE FUNCTION update_search_depth() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        UPDATE yandex_subscriptions SET search_depth=
            COALESCE((SELECT max(search_depth) FROM yandex_resources_subscriptions WHERE
                yandex_subscription_id=NEW.yandex_subscription_id AND datetime_unsubscribed IS NULL), 0)
            WHERE id=NEW.yandex_subscription_id;
        RETURN NULL;
    END;
$$;


ALTER FUNCTION public.update_search_depth() OWNER TO monitoringengine;

--
-- Name: yandex_searchresults_insert(); Type: FUNCTION; Schema: public; Owner: monitoringengine
--

CREATE OR REPLACE FUNCTION yandex_searchresults_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE new_hostname varchar(250);
            subscription record;
            new_url_id bigint;
            url_rec record;
    BEGIN
        -- и если нет, то пытаемся добавить
        BEGIN
            new_url_id := nextval('urls_id_seq');
            INSERT INTO urls (id, url) VALUES (new_url_id, NEW.url);
        EXCEPTION WHEN unique_violation THEN
            BEGIN
                SELECT id INTO STRICT url_rec FROM urls WHERE url = NEW.url;
                new_url_id := url_rec.id;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE EXCEPTION 'url % not found', NEW.url;
                WHEN TOO_MANY_ROWS THEN
                    RAISE EXCEPTION 'url % not unique', NEW.url;
            END;
        END;
        -- сохраняем позицию
        INSERT INTO yandex_results (url_id, position, yandex_subscription_id, timestamp, search_depth)
            VALUES (new_url_id, NEW.position, NEW.yandex_subscription_id, NEW.timestamp, NEW.search_depth);

        new_hostname := substring(NEW.url from '^.+://([^/]+)');
        FOR subscription IN SELECT yandex_accounts_subscriptions.id, yandex_accounts_subscriptions.search_depth,
                    yandex_accounts_subscriptions.subdomain_include, websites.hostname FROM yandex_accounts_subscriptions
                JOIN monitoringengine_ui_resource ON monitoringengine_ui_resource.id = yandex_accounts_subscriptions.resource_id
                JOIN websites ON websites.id = monitoringengine_ui_resource.website_id
                WHERE (datetime_unsubscribed is null or datetime_unsubscribed > current_date) AND
                    yandex_subscription_id = NEW.yandex_subscription_id LOOP
            IF subscription.search_depth >= NEW.position THEN
                -- если hostname подходит под заданный в подписке
                IF (new_hostname LIKE '%.' || subscription.hostname AND (subscription.subdomain_include='only_subdomains' OR
                           subscription.subdomain_include='domain_with_subdomains')) OR
                        (subscription.hostname = new_hostname AND (subscription.subdomain_include='strict_domain' OR
                           subscription.subdomain_include='domain_with_subdomains')) THEN
                    BEGIN
                        -- добавляем новые записи для поискового запроса с заданной глубиной поиска и пустой позицией
                        INSERT INTO  yandex_reports(yandex_account_subscription_id, datestamp, "position", search_depth)
                            VALUES (subscription.id, NEW.timestamp::DATE, NEW.position,
                                LEAST(subscription.search_depth, NEW.search_depth));
                    EXCEPTION WHEN unique_violation THEN
                    END;
                END IF;
            END IF;
        END LOOP;
        RETURN NULL;
    END;
$$;


ALTER FUNCTION public.yandex_searchresults_insert() OWNER TO monitoringengine;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE accounts (
    id integer NOT NULL,
    name character varying(80) NOT NULL,
    max_subscriptions_number integer
);


ALTER TABLE public.accounts OWNER TO monitoringengine;

--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.accounts_id_seq OWNER TO monitoringengine;

--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE accounts_id_seq OWNED BY accounts.id;


--
-- Name: auth_group; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE auth_group (
    id integer NOT NULL,
    name character varying(80) NOT NULL
);


ALTER TABLE public.auth_group OWNER TO monitoringengine;

--
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_group_id_seq OWNER TO monitoringengine;

--
-- Name: auth_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE auth_group_id_seq OWNED BY auth_group.id;


--
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE auth_group_permissions (
    id integer NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_group_permissions OWNER TO monitoringengine;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_group_permissions_id_seq OWNER TO monitoringengine;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE auth_group_permissions_id_seq OWNED BY auth_group_permissions.id;


--
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE auth_permission (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


ALTER TABLE public.auth_permission OWNER TO monitoringengine;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_permission_id_seq OWNER TO monitoringengine;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE auth_permission_id_seq OWNED BY auth_permission.id;


--
-- Name: auth_user; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE auth_user (
    id integer NOT NULL,
    username character varying(30) NOT NULL,
    first_name character varying(30) NOT NULL,
    last_name character varying(30) NOT NULL,
    email character varying(75) NOT NULL,
    password character varying(128) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    is_superuser boolean NOT NULL,
    last_login timestamp with time zone NOT NULL,
    date_joined timestamp with time zone NOT NULL
);


ALTER TABLE public.auth_user OWNER TO monitoringengine;

--
-- Name: auth_user_groups; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE auth_user_groups (
    id integer NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


ALTER TABLE public.auth_user_groups OWNER TO monitoringengine;

--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE auth_user_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_user_groups_id_seq OWNER TO monitoringengine;

--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE auth_user_groups_id_seq OWNED BY auth_user_groups.id;


--
-- Name: auth_user_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE auth_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_user_id_seq OWNER TO monitoringengine;

--
-- Name: auth_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE auth_user_id_seq OWNED BY auth_user.id;


--
-- Name: auth_user_user_permissions; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE auth_user_user_permissions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_user_user_permissions OWNER TO monitoringengine;

--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE auth_user_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_user_user_permissions_id_seq OWNER TO monitoringengine;

--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE auth_user_user_permissions_id_seq OWNED BY auth_user_user_permissions.id;


--
-- Name: authorisation_verificationkey; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE authorisation_verificationkey (
    id integer NOT NULL,
    user_id integer NOT NULL,
    key character varying(40) NOT NULL,
    created timestamp with time zone NOT NULL,
    unused boolean NOT NULL
);


ALTER TABLE public.authorisation_verificationkey OWNER TO monitoringengine;

--
-- Name: authorisation_verificationkey_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE authorisation_verificationkey_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.authorisation_verificationkey_id_seq OWNER TO monitoringengine;

--
-- Name: authorisation_verificationkey_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE authorisation_verificationkey_id_seq OWNED BY authorisation_verificationkey.id;


--
-- Name: django_admin_log; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    user_id integer NOT NULL,
    content_type_id integer,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


ALTER TABLE public.django_admin_log OWNER TO monitoringengine;

--
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.django_admin_log_id_seq OWNER TO monitoringengine;

--
-- Name: django_admin_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE django_admin_log_id_seq OWNED BY django_admin_log.id;


--
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE django_content_type (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


ALTER TABLE public.django_content_type OWNER TO monitoringengine;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.django_content_type_id_seq OWNER TO monitoringengine;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE django_content_type_id_seq OWNED BY django_content_type.id;


--
-- Name: django_redirect; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE django_redirect (
    id integer NOT NULL,
    site_id integer NOT NULL,
    old_path character varying(200) NOT NULL,
    new_path character varying(200) NOT NULL
);


ALTER TABLE public.django_redirect OWNER TO monitoringengine;

--
-- Name: django_redirect_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE django_redirect_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.django_redirect_id_seq OWNER TO monitoringengine;

--
-- Name: django_redirect_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE django_redirect_id_seq OWNED BY django_redirect.id;


--
-- Name: django_session; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


ALTER TABLE public.django_session OWNER TO monitoringengine;

--
-- Name: django_site; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE django_site (
    id integer NOT NULL,
    domain character varying(100) NOT NULL,
    name character varying(50) NOT NULL
);


ALTER TABLE public.django_site OWNER TO monitoringengine;

--
-- Name: django_site_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE django_site_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.django_site_id_seq OWNER TO monitoringengine;

--
-- Name: django_site_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE django_site_id_seq OWNED BY django_site.id;


--
-- Name: monitoringengine_ui_accountpermission; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE monitoringengine_ui_accountpermission (
    id integer NOT NULL,
    account_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.monitoringengine_ui_accountpermission OWNER TO monitoringengine;

--
-- Name: monitoringengine_ui_accountpermission_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE monitoringengine_ui_accountpermission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.monitoringengine_ui_accountpermission_id_seq OWNER TO monitoringengine;

--
-- Name: monitoringengine_ui_accountpermission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE monitoringengine_ui_accountpermission_id_seq OWNED BY monitoringengine_ui_accountpermission.id;


--
-- Name: monitoringengine_ui_resourcepermission; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE monitoringengine_ui_resourcepermission (
    id integer NOT NULL,
    resource_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.monitoringengine_ui_resourcepermission OWNER TO monitoringengine;

--
-- Name: monitoringengine_ui_resourcepermission_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE monitoringengine_ui_resourcepermission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.monitoringengine_ui_resourcepermission_id_seq OWNER TO monitoringengine;

--
-- Name: monitoringengine_ui_resourcepermission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE monitoringengine_ui_resourcepermission_id_seq OWNED BY monitoringengine_ui_resourcepermission.id;


--
-- Name: monitoringengine_ui_viewpermission; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE monitoringengine_ui_viewpermission (
    id integer NOT NULL,
    view_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.monitoringengine_ui_viewpermission OWNER TO monitoringengine;

--
-- Name: monitoringengine_ui_viewpermission_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE monitoringengine_ui_viewpermission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.monitoringengine_ui_viewpermission_id_seq OWNER TO monitoringengine;

--
-- Name: monitoringengine_ui_viewpermission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE monitoringengine_ui_viewpermission_id_seq OWNED BY monitoringengine_ui_viewpermission.id;


--
-- Name: queries; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE queries (
    id integer NOT NULL,
    querystring character varying(250) NOT NULL
);


ALTER TABLE public.queries OWNER TO monitoringengine;

--
-- Name: queries_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.queries_id_seq OWNER TO monitoringengine;

--
-- Name: queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE queries_id_seq OWNED BY queries.id;


--
-- Name: resources; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE resources (
    id integer NOT NULL,
    account_id integer NOT NULL,
    website_id integer NOT NULL,
    note character varying(250)
);


ALTER TABLE public.resources OWNER TO monitoringengine;

--
-- Name: resources_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE resources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.resources_id_seq OWNER TO monitoringengine;

--
-- Name: resources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE resources_id_seq OWNED BY resources.id;


--
-- Name: social_auth_association; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE social_auth_association (
    id integer NOT NULL,
    server_url character varying(255) NOT NULL,
    handle character varying(255) NOT NULL,
    secret character varying(255) NOT NULL,
    issued integer NOT NULL,
    lifetime integer NOT NULL,
    assoc_type character varying(64) NOT NULL
);


ALTER TABLE public.social_auth_association OWNER TO monitoringengine;

--
-- Name: social_auth_association_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE social_auth_association_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.social_auth_association_id_seq OWNER TO monitoringengine;

--
-- Name: social_auth_association_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE social_auth_association_id_seq OWNED BY social_auth_association.id;


--
-- Name: social_auth_nonce; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE social_auth_nonce (
    id integer NOT NULL,
    server_url character varying(255) NOT NULL,
    "timestamp" integer NOT NULL,
    salt character varying(40) NOT NULL
);


ALTER TABLE public.social_auth_nonce OWNER TO monitoringengine;

--
-- Name: social_auth_nonce_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE social_auth_nonce_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.social_auth_nonce_id_seq OWNER TO monitoringengine;

--
-- Name: social_auth_nonce_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE social_auth_nonce_id_seq OWNED BY social_auth_nonce.id;


--
-- Name: social_auth_usersocialauth; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE social_auth_usersocialauth (
    id integer NOT NULL,
    user_id integer NOT NULL,
    provider character varying(32) NOT NULL,
    uid character varying(255) NOT NULL,
    extra_data text NOT NULL
);


ALTER TABLE public.social_auth_usersocialauth OWNER TO monitoringengine;

--
-- Name: social_auth_usersocialauth_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE social_auth_usersocialauth_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.social_auth_usersocialauth_id_seq OWNER TO monitoringengine;

--
-- Name: social_auth_usersocialauth_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE social_auth_usersocialauth_id_seq OWNED BY social_auth_usersocialauth.id;


--
-- Name: urls; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE urls (
    id bigint NOT NULL,
    url text NOT NULL
);


ALTER TABLE public.urls OWNER TO monitoringengine;

--
-- Name: urls_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE urls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.urls_id_seq OWNER TO monitoringengine;

--
-- Name: urls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE urls_id_seq OWNED BY urls.id;


--
-- Name: views; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE views (
    id integer NOT NULL,
    name character varying(255),
    last_changed timestamp without time zone NOT NULL,
    resource_id integer NOT NULL
);


ALTER TABLE public.views OWNER TO monitoringengine;

--
-- Name: views_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.views_id_seq OWNER TO monitoringengine;

--
-- Name: views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE views_id_seq OWNED BY views.id;


--
-- Name: websites; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE websites (
    id integer NOT NULL,
    hostname character varying(250) NOT NULL
);


ALTER TABLE public.websites OWNER TO monitoringengine;

--
-- Name: websites_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE websites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.websites_id_seq OWNER TO monitoringengine;

--
-- Name: websites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE websites_id_seq OWNED BY websites.id;


--
-- Name: yandex_regions; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE yandex_regions (
    id integer NOT NULL,
    name character varying(250) NOT NULL,
    code integer NOT NULL
);


ALTER TABLE public.yandex_regions OWNER TO monitoringengine;

--
-- Name: yandex_regions_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE yandex_regions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.yandex_regions_id_seq OWNER TO monitoringengine;

--
-- Name: yandex_regions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE yandex_regions_id_seq OWNED BY yandex_regions.id;


--
-- Name: yandex_reports; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE yandex_reports (
    id integer NOT NULL,
    yandex_account_subscription_id integer,
    "position" integer,
    search_depth integer,
    datestamp date
);


ALTER TABLE public.yandex_reports OWNER TO monitoringengine;

--
-- Name: yandex_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE yandex_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.yandex_reports_id_seq OWNER TO monitoringengine;

--
-- Name: yandex_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE yandex_reports_id_seq OWNED BY yandex_reports.id;


--
-- Name: yandex_resources_subscriptions; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE yandex_resources_subscriptions (
    id integer NOT NULL,
    yandex_subscription_id integer NOT NULL,
    resource_id integer NOT NULL,
    datetime_subscribed timestamp without time zone NOT NULL,
    datetime_unsubscribed timestamp without time zone,
    search_depth integer DEFAULT 200,
    subdomain_include subdomain_include_type NOT NULL
);


ALTER TABLE public.yandex_resources_subscriptions OWNER TO monitoringengine;

--
-- Name: yandex_resources_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE yandex_resources_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.yandex_resources_subscriptions_id_seq OWNER TO monitoringengine;

--
-- Name: yandex_resources_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE yandex_resources_subscriptions_id_seq OWNED BY yandex_resources_subscriptions.id;


--
-- Name: yandex_results; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE yandex_results (
    id bigint NOT NULL,
    yandex_subscription_id integer,
    url_id bigint NOT NULL,
    "position" integer,
    search_depth integer,
    "timestamp" timestamp without time zone
);


ALTER TABLE public.yandex_results OWNER TO monitoringengine;

--
-- Name: yandex_results_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE yandex_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.yandex_results_id_seq OWNER TO monitoringengine;

--
-- Name: yandex_results_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE yandex_results_id_seq OWNED BY yandex_results.id;


--
-- Name: yandex_searchresults; Type: VIEW; Schema: public; Owner: monitoringengine
--

CREATE VIEW yandex_searchresults AS
    SELECT yandex_results.id, urls.url, yandex_results."position", yandex_results.search_depth, yandex_results.yandex_subscription_id, yandex_results."timestamp" FROM (yandex_results LEFT JOIN urls ON ((urls.id = yandex_results.url_id)));


ALTER TABLE public.yandex_searchresults OWNER TO monitoringengine;

--
-- Name: yandex_searchresults_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE yandex_searchresults_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.yandex_searchresults_id_seq OWNER TO monitoringengine;

--
-- Name: yandex_subscriptions; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE yandex_subscriptions (
    id integer NOT NULL,
    query_id integer NOT NULL,
    yandex_region_id integer NOT NULL,
    search_depth integer
);


ALTER TABLE public.yandex_subscriptions OWNER TO monitoringengine;

--
-- Name: yandex_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE yandex_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.yandex_subscriptions_id_seq OWNER TO monitoringengine;

--
-- Name: yandex_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE yandex_subscriptions_id_seq OWNED BY yandex_subscriptions.id;


--
-- Name: yandex_view_entries; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE yandex_view_entries (
    id integer NOT NULL,
    sorting_order integer NOT NULL,
    view_id integer NOT NULL,
    yandex_resources_subscriptions_id integer NOT NULL
);


ALTER TABLE public.yandex_view_entries OWNER TO monitoringengine;

--
-- Name: yandex_view_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE yandex_view_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.yandex_view_entries_id_seq OWNER TO monitoringengine;

--
-- Name: yandex_view_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE yandex_view_entries_id_seq OWNED BY yandex_view_entries.id;


--
-- Name: yandex_wordstat; Type: TABLE; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE TABLE yandex_wordstat (
    id integer NOT NULL,
    yandex_subscription_id integer NOT NULL,
    common_quantity integer NOT NULL,
    "timestamp" timestamp without time zone NOT NULL
);


ALTER TABLE public.yandex_wordstat OWNER TO monitoringengine;

--
-- Name: yandex_wordstat_id_seq; Type: SEQUENCE; Schema: public; Owner: monitoringengine
--

CREATE SEQUENCE yandex_wordstat_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.yandex_wordstat_id_seq OWNER TO monitoringengine;

--
-- Name: yandex_wordstat_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monitoringengine
--

ALTER SEQUENCE yandex_wordstat_id_seq OWNED BY yandex_wordstat.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY accounts ALTER COLUMN id SET DEFAULT nextval('accounts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_group ALTER COLUMN id SET DEFAULT nextval('auth_group_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_group_permissions ALTER COLUMN id SET DEFAULT nextval('auth_group_permissions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_permission ALTER COLUMN id SET DEFAULT nextval('auth_permission_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_user ALTER COLUMN id SET DEFAULT nextval('auth_user_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_user_groups ALTER COLUMN id SET DEFAULT nextval('auth_user_groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_user_user_permissions ALTER COLUMN id SET DEFAULT nextval('auth_user_user_permissions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY authorisation_verificationkey ALTER COLUMN id SET DEFAULT nextval('authorisation_verificationkey_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY django_admin_log ALTER COLUMN id SET DEFAULT nextval('django_admin_log_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY django_content_type ALTER COLUMN id SET DEFAULT nextval('django_content_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY django_redirect ALTER COLUMN id SET DEFAULT nextval('django_redirect_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY django_site ALTER COLUMN id SET DEFAULT nextval('django_site_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY monitoringengine_ui_accountpermission ALTER COLUMN id SET DEFAULT nextval('monitoringengine_ui_accountpermission_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY monitoringengine_ui_resourcepermission ALTER COLUMN id SET DEFAULT nextval('monitoringengine_ui_resourcepermission_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY monitoringengine_ui_viewpermission ALTER COLUMN id SET DEFAULT nextval('monitoringengine_ui_viewpermission_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY queries ALTER COLUMN id SET DEFAULT nextval('queries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY resources ALTER COLUMN id SET DEFAULT nextval('resources_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY social_auth_association ALTER COLUMN id SET DEFAULT nextval('social_auth_association_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY social_auth_nonce ALTER COLUMN id SET DEFAULT nextval('social_auth_nonce_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY social_auth_usersocialauth ALTER COLUMN id SET DEFAULT nextval('social_auth_usersocialauth_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY urls ALTER COLUMN id SET DEFAULT nextval('urls_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY websites ALTER COLUMN id SET DEFAULT nextval('websites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_regions ALTER COLUMN id SET DEFAULT nextval('yandex_regions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_reports ALTER COLUMN id SET DEFAULT nextval('yandex_reports_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_resources_subscriptions ALTER COLUMN id SET DEFAULT nextval('yandex_resources_subscriptions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_results ALTER COLUMN id SET DEFAULT nextval('yandex_results_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_subscriptions ALTER COLUMN id SET DEFAULT nextval('yandex_subscriptions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_wordstat ALTER COLUMN id SET DEFAULT nextval('yandex_wordstat_id_seq'::regclass);


--
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY accounts (id, name, max_subscriptions_number) FROM stdin;
1	Test	0
\.


--
-- Name: accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('accounts_id_seq', 1, true);


--
-- Data for Name: auth_group; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY auth_group (id, name) FROM stdin;
\.


--
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('auth_group_id_seq', 1, false);


--
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY auth_group_permissions (id, group_id, permission_id) FROM stdin;
\.


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('auth_group_permissions_id_seq', 1, false);


--
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY auth_permission (id, name, content_type_id, codename) FROM stdin;
1	Can add permission	1	add_permission
2	Can change permission	1	change_permission
3	Can delete permission	1	delete_permission
4	Can add group	2	add_group
5	Can change group	2	change_group
6	Can delete group	2	delete_group
7	Can add user	3	add_user
8	Can change user	3	change_user
9	Can delete user	3	delete_user
10	Can add content type	4	add_contenttype
11	Can change content type	4	change_contenttype
12	Can delete content type	4	delete_contenttype
13	Can add session	5	add_session
14	Can change session	5	change_session
15	Can delete session	5	delete_session
16	Can add log entry	6	add_logentry
17	Can change log entry	6	change_logentry
18	Can delete log entry	6	delete_logentry
19	Can add site	7	add_site
20	Can change site	7	change_site
21	Can delete site	7	delete_site
22	Can add redirect	8	add_redirect
23	Can change redirect	8	change_redirect
24	Can delete redirect	8	delete_redirect
25	Can add account	9	add_account
26	Can change account	9	change_account
27	Can delete account	9	delete_account
28	Can add website	10	add_website
29	Can change website	10	change_website
30	Can delete website	10	delete_website
37	Can add verification key	12	add_verificationkey
38	Can change verification key	12	change_verificationkey
39	Can delete verification key	12	delete_verificationkey
40	Can add user social auth	13	add_usersocialauth
41	Can change user social auth	13	change_usersocialauth
42	Can delete user social auth	13	delete_usersocialauth
43	Can add nonce	14	add_nonce
44	Can change nonce	14	change_nonce
45	Can delete nonce	14	delete_nonce
46	Can add association	15	add_association
47	Can change association	15	change_association
48	Can delete association	15	delete_association
49	Can add resource	17	add_resource
50	Can change resource	17	change_resource
51	Can delete resource	17	delete_resource
52	Can add view	18	add_view
53	Can change view	18	change_view
54	Can delete view	18	delete_view
55	Can add account permission	19	add_accountpermission
56	Can change account permission	19	change_accountpermission
57	Can delete account permission	19	delete_accountpermission
58	Can add resource permission	20	add_resourcepermission
59	Can change resource permission	20	change_resourcepermission
60	Can delete resource permission	20	delete_resourcepermission
61	Can add view permission	21	add_viewpermission
62	Can change view permission	21	change_viewpermission
63	Can delete view permission	21	delete_viewpermission
64	Can read account 1	9	can_read_account_1
\.


--
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('auth_permission_id_seq', 64, true);


--
-- Data for Name: auth_user; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY auth_user (id, username, first_name, last_name, email, password, is_staff, is_active, is_superuser, last_login, date_joined) FROM stdin;
1	test			test@example.com	pbkdf2_sha256$10000$MTMdeMe8LryR$+QeRNQARaIXHIHNU12uAqHaF1gglp2HGW/lpr/VPn5Y=	f	t	f	2013-07-23 13:14:26.229206+06	2013-07-23 13:11:39.536356+06
2	administrator			1@1.ru	pbkdf2_sha256$10000$iUZOXNJrPyFB$v8H0fcqsHkN+9urFr06O8C4wSVATv4xaisGfjGq/ndA=	t	t	t	2013-07-23 14:45:13.481764+06	2013-07-23 14:45:04.118885+06
\.


--
-- Data for Name: auth_user_groups; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY auth_user_groups (id, user_id, group_id) FROM stdin;
\.


--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('auth_user_groups_id_seq', 1, false);


--
-- Name: auth_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('auth_user_id_seq', 2, true);


--
-- Data for Name: auth_user_user_permissions; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY auth_user_user_permissions (id, user_id, permission_id) FROM stdin;
2	1	64
\.


--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('auth_user_user_permissions_id_seq', 2, true);


--
-- Data for Name: authorisation_verificationkey; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY authorisation_verificationkey (id, user_id, key, created, unused) FROM stdin;
\.


--
-- Name: authorisation_verificationkey_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('authorisation_verificationkey_id_seq', 1, false);


--
-- Data for Name: django_admin_log; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY django_admin_log (id, action_time, user_id, content_type_id, object_id, object_repr, action_flag, change_message) FROM stdin;
\.


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('django_admin_log_id_seq', 1, true);


--
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY django_content_type (id, name, app_label, model) FROM stdin;
1	permission	auth	permission
2	group	auth	group
3	user	auth	user
4	content type	contenttypes	contenttype
5	session	sessions	session
6	log entry	admin	logentry
7	site	sites	site
8	redirect	redirects	redirect
9	account	monitoringengine_ui	account
10	website	monitoringengine_ui	website
12	verification key	authorisation	verificationkey
13	user social auth	social_auth	usersocialauth
14	nonce	social_auth	nonce
15	association	social_auth	association
17	resource	monitoringengine_ui	resource
18	view	monitoringengine_ui	view
19	account permission	monitoringengine_ui	accountpermission
20	resource permission	monitoringengine_ui	resourcepermission
21	view permission	monitoringengine_ui	viewpermission
\.


--
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('django_content_type_id_seq', 21, true);


--
-- Data for Name: django_redirect; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY django_redirect (id, site_id, old_path, new_path) FROM stdin;
\.


--
-- Name: django_redirect_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('django_redirect_id_seq', 1, false);


--
-- Data for Name: django_session; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY django_session (session_key, session_data, expire_date) FROM stdin;
8fcd29e28ff632ebb4c74db866addd9e	ZjI1ZjVhNmY1NmFjMWYyNTkyNjRmMTM4ODY1ZjJhYmM5ZmZlYzRlYzqAAn1xAShVEl9hdXRoX3Vz\nZXJfYmFja2VuZHECVSlkamFuZ28uY29udHJpYi5hdXRoLmJhY2tlbmRzLk1vZGVsQmFja2VuZHED\nVQ1fYXV0aF91c2VyX2lkcQRLAnUu\n	2013-08-06 14:45:13.494116+06
\.


--
-- Data for Name: django_site; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY django_site (id, domain, name) FROM stdin;
1	example.com	example.com
\.


--
-- Name: django_site_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('django_site_id_seq', 1, true);


--
-- Data for Name: monitoringengine_ui_accountpermission; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY monitoringengine_ui_accountpermission (id, account_id, permission_id) FROM stdin;
1	1	64
\.


--
-- Name: monitoringengine_ui_accountpermission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('monitoringengine_ui_accountpermission_id_seq', 1, true);


--
-- Data for Name: monitoringengine_ui_resourcepermission; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY monitoringengine_ui_resourcepermission (id, resource_id, permission_id) FROM stdin;
\.


--
-- Name: monitoringengine_ui_resourcepermission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('monitoringengine_ui_resourcepermission_id_seq', 1, false);


--
-- Data for Name: monitoringengine_ui_viewpermission; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY monitoringengine_ui_viewpermission (id, view_id, permission_id) FROM stdin;
\.


--
-- Name: monitoringengine_ui_viewpermission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('monitoringengine_ui_viewpermission_id_seq', 1, false);


--
-- Data for Name: queries; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY queries (id, querystring) FROM stdin;
\.


--
-- Name: queries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('queries_id_seq', 1, false);


--
-- Data for Name: resources; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY resources (id, account_id, website_id, note) FROM stdin;
1	1	1	\N
\.


--
-- Name: resources_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('resources_id_seq', 1, true);


--
-- Data for Name: social_auth_association; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY social_auth_association (id, server_url, handle, secret, issued, lifetime, assoc_type) FROM stdin;
\.


--
-- Name: social_auth_association_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('social_auth_association_id_seq', 1, false);


--
-- Data for Name: social_auth_nonce; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY social_auth_nonce (id, server_url, "timestamp", salt) FROM stdin;
\.


--
-- Name: social_auth_nonce_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('social_auth_nonce_id_seq', 1, false);


--
-- Data for Name: social_auth_usersocialauth; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY social_auth_usersocialauth (id, user_id, provider, uid, extra_data) FROM stdin;
\.


--
-- Name: social_auth_usersocialauth_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('social_auth_usersocialauth_id_seq', 1, false);


--
-- Data for Name: urls; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY urls (id, url) FROM stdin;
\.


--
-- Name: urls_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('urls_id_seq', 1, false);


--
-- Data for Name: views; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY views (id, name, last_changed, resource_id) FROM stdin;
\.


--
-- Name: views_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('views_id_seq', 1, false);


--
-- Data for Name: websites; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY websites (id, hostname) FROM stdin;
1	example.com
\.


--
-- Name: websites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('websites_id_seq', 1, true);


--
-- Data for Name: yandex_regions; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY yandex_regions (id, name, code) FROM stdin;
1	Москва	213
2	Челябинск	56
3	Екатеринбург	54
4	Курган	53
6	Санкт-Петербург	2
7	Пермь	50
8	Тюмень	55
9	Салехард	58
10	Ханты - Мансийск	57
11	Алматы	162
12	Астана	163
13	Костанай	10295
5	Иваново	5
14	test	123
\.


--
-- Name: yandex_regions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('yandex_regions_id_seq', 14, true);


--
-- Data for Name: yandex_reports; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY yandex_reports (id, yandex_account_subscription_id, "position", search_depth, datestamp) FROM stdin;
\.


--
-- Name: yandex_reports_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('yandex_reports_id_seq', 1, false);


--
-- Data for Name: yandex_resources_subscriptions; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY yandex_resources_subscriptions (id, yandex_subscription_id, resource_id, datetime_subscribed, datetime_unsubscribed, search_depth, subdomain_include) FROM stdin;
\.


--
-- Name: yandex_resources_subscriptions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('yandex_resources_subscriptions_id_seq', 1, false);


--
-- Data for Name: yandex_results; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY yandex_results (id, yandex_subscription_id, url_id, "position", search_depth, "timestamp") FROM stdin;
\.


--
-- Name: yandex_results_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('yandex_results_id_seq', 1, false);


--
-- Name: yandex_searchresults_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('yandex_searchresults_id_seq', 1, false);


--
-- Data for Name: yandex_subscriptions; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY yandex_subscriptions (id, query_id, yandex_region_id, search_depth) FROM stdin;
\.


--
-- Name: yandex_subscriptions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('yandex_subscriptions_id_seq', 1, false);


--
-- Data for Name: yandex_view_entries; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY yandex_view_entries (id, sorting_order, view_id, yandex_resources_subscriptions_id) FROM stdin;
\.


--
-- Name: yandex_view_entries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('yandex_view_entries_id_seq', 1, false);


--
-- Data for Name: yandex_wordstat; Type: TABLE DATA; Schema: public; Owner: monitoringengine
--

COPY yandex_wordstat (id, yandex_subscription_id, common_quantity, "timestamp") FROM stdin;
\.


--
-- Name: yandex_wordstat_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monitoringengine
--

SELECT pg_catalog.setval('yandex_wordstat_id_seq', 1, false);


--
-- Name: accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- Name: auth_group_permissions_group_id_permission_id_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_key UNIQUE (group_id, permission_id);


--
-- Name: auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- Name: auth_permission_content_type_id_codename_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_key UNIQUE (content_type_id, codename);


--
-- Name: auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups_user_id_group_id_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_group_id_key UNIQUE (user_id, group_id);


--
-- Name: auth_user_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY auth_user
    ADD CONSTRAINT auth_user_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions_user_id_permission_id_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_permission_id_key UNIQUE (user_id, permission_id);


--
-- Name: auth_user_username_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY auth_user
    ADD CONSTRAINT auth_user_username_key UNIQUE (username);


--
-- Name: authorisation_verificationkey_key_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY authorisation_verificationkey
    ADD CONSTRAINT authorisation_verificationkey_key_key UNIQUE (key);


--
-- Name: authorisation_verificationkey_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY authorisation_verificationkey
    ADD CONSTRAINT authorisation_verificationkey_pkey PRIMARY KEY (id);


--
-- Name: django_admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- Name: django_content_type_app_label_model_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_key UNIQUE (app_label, model);


--
-- Name: django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- Name: django_redirect_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY django_redirect
    ADD CONSTRAINT django_redirect_pkey PRIMARY KEY (id);


--
-- Name: django_redirect_site_id_old_path_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY django_redirect
    ADD CONSTRAINT django_redirect_site_id_old_path_key UNIQUE (site_id, old_path);


--
-- Name: django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- Name: django_site_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY django_site
    ADD CONSTRAINT django_site_pkey PRIMARY KEY (id);


--
-- Name: monitoringengine_ui_accountpermission_permission_id_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY monitoringengine_ui_accountpermission
    ADD CONSTRAINT monitoringengine_ui_accountpermission_permission_id_key UNIQUE (permission_id);


--
-- Name: monitoringengine_ui_accountpermission_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY monitoringengine_ui_accountpermission
    ADD CONSTRAINT monitoringengine_ui_accountpermission_pkey PRIMARY KEY (id);


--
-- Name: monitoringengine_ui_resourcepermission_permission_id_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY monitoringengine_ui_resourcepermission
    ADD CONSTRAINT monitoringengine_ui_resourcepermission_permission_id_key UNIQUE (permission_id);


--
-- Name: monitoringengine_ui_resourcepermission_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY monitoringengine_ui_resourcepermission
    ADD CONSTRAINT monitoringengine_ui_resourcepermission_pkey PRIMARY KEY (id);


--
-- Name: monitoringengine_ui_viewpermission_permission_id_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY monitoringengine_ui_viewpermission
    ADD CONSTRAINT monitoringengine_ui_viewpermission_permission_id_key UNIQUE (permission_id);


--
-- Name: monitoringengine_ui_viewpermission_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY monitoringengine_ui_viewpermission
    ADD CONSTRAINT monitoringengine_ui_viewpermission_pkey PRIMARY KEY (id);


--
-- Name: queries_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY queries
    ADD CONSTRAINT queries_pkey PRIMARY KEY (id);


--
-- Name: resources_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY resources
    ADD CONSTRAINT resources_pkey PRIMARY KEY (id);


--
-- Name: social_auth_association_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY social_auth_association
    ADD CONSTRAINT social_auth_association_pkey PRIMARY KEY (id);


--
-- Name: social_auth_association_server_url_handle_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY social_auth_association
    ADD CONSTRAINT social_auth_association_server_url_handle_key UNIQUE (server_url, handle);


--
-- Name: social_auth_nonce_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY social_auth_nonce
    ADD CONSTRAINT social_auth_nonce_pkey PRIMARY KEY (id);


--
-- Name: social_auth_nonce_server_url_timestamp_salt_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY social_auth_nonce
    ADD CONSTRAINT social_auth_nonce_server_url_timestamp_salt_key UNIQUE (server_url, "timestamp", salt);


--
-- Name: social_auth_usersocialauth_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY social_auth_usersocialauth
    ADD CONSTRAINT social_auth_usersocialauth_pkey PRIMARY KEY (id);


--
-- Name: social_auth_usersocialauth_provider_uid_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY social_auth_usersocialauth
    ADD CONSTRAINT social_auth_usersocialauth_provider_uid_key UNIQUE (provider, uid);


--
-- Name: urls_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY urls
    ADD CONSTRAINT urls_pkey PRIMARY KEY (id);


--
-- Name: urls_url_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY urls
    ADD CONSTRAINT urls_url_key UNIQUE (url);


--
-- Name: views_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY views
    ADD CONSTRAINT views_pkey PRIMARY KEY (id);


--
-- Name: websites_hostname_key; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY websites
    ADD CONSTRAINT websites_hostname_key UNIQUE (hostname);


--
-- Name: websites_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY websites
    ADD CONSTRAINT websites_pkey PRIMARY KEY (id);


--
-- Name: yandex_regions_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY yandex_regions
    ADD CONSTRAINT yandex_regions_pkey PRIMARY KEY (id);


--
-- Name: yandex_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY yandex_reports
    ADD CONSTRAINT yandex_reports_pkey PRIMARY KEY (id);


--
-- Name: yandex_reports_unique; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY yandex_reports
    ADD CONSTRAINT yandex_reports_unique UNIQUE (yandex_account_subscription_id, datestamp, "position");


--
-- Name: yandex_resources_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY yandex_resources_subscriptions
    ADD CONSTRAINT yandex_resources_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: yandex_results_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY yandex_results
    ADD CONSTRAINT yandex_results_pkey PRIMARY KEY (id);


--
-- Name: yandex_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY yandex_subscriptions
    ADD CONSTRAINT yandex_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: yandex_view_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY yandex_view_entries
    ADD CONSTRAINT yandex_view_entries_pkey PRIMARY KEY (id);


--
-- Name: yandex_wordstat_pkey; Type: CONSTRAINT; Schema: public; Owner: monitoringengine; Tablespace: 
--

ALTER TABLE ONLY yandex_wordstat
    ADD CONSTRAINT yandex_wordstat_pkey PRIMARY KEY (id);


--
-- Name: auth_group_permissions_group_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX auth_group_permissions_group_id ON auth_group_permissions USING btree (group_id);


--
-- Name: auth_group_permissions_permission_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX auth_group_permissions_permission_id ON auth_group_permissions USING btree (permission_id);


--
-- Name: auth_permission_content_type_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX auth_permission_content_type_id ON auth_permission USING btree (content_type_id);


--
-- Name: auth_user_groups_group_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX auth_user_groups_group_id ON auth_user_groups USING btree (group_id);


--
-- Name: auth_user_groups_user_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX auth_user_groups_user_id ON auth_user_groups USING btree (user_id);


--
-- Name: auth_user_user_permissions_permission_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX auth_user_user_permissions_permission_id ON auth_user_user_permissions USING btree (permission_id);


--
-- Name: auth_user_user_permissions_user_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX auth_user_user_permissions_user_id ON auth_user_user_permissions USING btree (user_id);


--
-- Name: authorisation_verificationkey_user_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX authorisation_verificationkey_user_id ON authorisation_verificationkey USING btree (user_id);


--
-- Name: django_admin_log_content_type_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX django_admin_log_content_type_id ON django_admin_log USING btree (content_type_id);


--
-- Name: django_admin_log_user_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX django_admin_log_user_id ON django_admin_log USING btree (user_id);


--
-- Name: django_redirect_old_path; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX django_redirect_old_path ON django_redirect USING btree (old_path);


--
-- Name: django_redirect_old_path_like; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX django_redirect_old_path_like ON django_redirect USING btree (old_path varchar_pattern_ops);


--
-- Name: django_redirect_site_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX django_redirect_site_id ON django_redirect USING btree (site_id);


--
-- Name: django_session_expire_date; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX django_session_expire_date ON django_session USING btree (expire_date);


--
-- Name: monitoringengine_ui_accountpermission_account_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX monitoringengine_ui_accountpermission_account_id ON monitoringengine_ui_accountpermission USING btree (account_id);


--
-- Name: monitoringengine_ui_resourcepermission_resource_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX monitoringengine_ui_resourcepermission_resource_id ON monitoringengine_ui_resourcepermission USING btree (resource_id);


--
-- Name: monitoringengine_ui_viewpermission_view_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX monitoringengine_ui_viewpermission_view_id ON monitoringengine_ui_viewpermission USING btree (view_id);


--
-- Name: social_auth_association_issued; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX social_auth_association_issued ON social_auth_association USING btree (issued);


--
-- Name: social_auth_nonce_timestamp; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX social_auth_nonce_timestamp ON social_auth_nonce USING btree ("timestamp");


--
-- Name: social_auth_usersocialauth_user_id; Type: INDEX; Schema: public; Owner: monitoringengine; Tablespace: 
--

CREATE INDEX social_auth_usersocialauth_user_id ON social_auth_usersocialauth USING btree (user_id);


--
-- Name: yandex_resources_subscriptions_search_depth; Type: TRIGGER; Schema: public; Owner: monitoringengine
--

CREATE TRIGGER yandex_resources_subscriptions_search_depth AFTER INSERT OR UPDATE ON yandex_resources_subscriptions FOR EACH ROW EXECUTE PROCEDURE update_search_depth();


--
-- Name: yandex_searchresults_insert; Type: TRIGGER; Schema: public; Owner: monitoringengine
--

CREATE OR REPLACE  TRIGGER yandex_searchresults_insert INSTEAD OF INSERT ON yandex_searchresults FOR EACH ROW EXECUTE PROCEDURE yandex_searchresults_insert();


--
-- Name: auth_group_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_group_id_fkey FOREIGN KEY (group_id) REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: authorisation_verificationkey_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY authorisation_verificationkey
    ADD CONSTRAINT authorisation_verificationkey_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: content_type_id_refs_id_728de91f; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT content_type_id_refs_id_728de91f FOREIGN KEY (content_type_id) REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log_content_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_fkey FOREIGN KEY (content_type_id) REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_redirect_site_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY django_redirect
    ADD CONSTRAINT django_redirect_site_id_fkey FOREIGN KEY (site_id) REFERENCES django_site(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: group_id_refs_id_3cea63fe; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT group_id_refs_id_3cea63fe FOREIGN KEY (group_id) REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: monitoringengine_ui_accountpermission_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY monitoringengine_ui_accountpermission
    ADD CONSTRAINT monitoringengine_ui_accountpermission_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: monitoringengine_ui_accountpermission_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY monitoringengine_ui_accountpermission
    ADD CONSTRAINT monitoringengine_ui_accountpermission_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: monitoringengine_ui_resourcepermission_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY monitoringengine_ui_resourcepermission
    ADD CONSTRAINT monitoringengine_ui_resourcepermission_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: monitoringengine_ui_resourcepermission_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY monitoringengine_ui_resourcepermission
    ADD CONSTRAINT monitoringengine_ui_resourcepermission_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES resources(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: monitoringengine_ui_viewpermission_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY monitoringengine_ui_viewpermission
    ADD CONSTRAINT monitoringengine_ui_viewpermission_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: monitoringengine_ui_viewpermission_view_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY monitoringengine_ui_viewpermission
    ADD CONSTRAINT monitoringengine_ui_viewpermission_view_id_fkey FOREIGN KEY (view_id) REFERENCES views(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: resources_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY resources
    ADD CONSTRAINT resources_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(id);


--
-- Name: resources_website_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY resources
    ADD CONSTRAINT resources_website_id_fkey FOREIGN KEY (website_id) REFERENCES websites(id);


--
-- Name: social_auth_usersocialauth_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY social_auth_usersocialauth
    ADD CONSTRAINT social_auth_usersocialauth_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_id_refs_id_831107f1; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT user_id_refs_id_831107f1 FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_id_refs_id_f2045483; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT user_id_refs_id_f2045483 FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: views_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY views
    ADD CONSTRAINT views_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES resources(id);


--
-- Name: yandex_reports_yandex_account_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_reports
    ADD CONSTRAINT yandex_reports_yandex_account_subscription_id_fkey FOREIGN KEY (yandex_account_subscription_id) REFERENCES yandex_resources_subscriptions(id);


--
-- Name: yandex_resources_subscriptions_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_resources_subscriptions
    ADD CONSTRAINT yandex_resources_subscriptions_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES resources(id);


--
-- Name: yandex_resources_subscriptions_yandex_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_resources_subscriptions
    ADD CONSTRAINT yandex_resources_subscriptions_yandex_subscription_id_fkey FOREIGN KEY (yandex_subscription_id) REFERENCES yandex_subscriptions(id);


--
-- Name: yandex_results_url_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_results
    ADD CONSTRAINT yandex_results_url_id_fkey FOREIGN KEY (url_id) REFERENCES urls(id);


--
-- Name: yandex_results_yandex_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_results
    ADD CONSTRAINT yandex_results_yandex_subscription_id_fkey FOREIGN KEY (yandex_subscription_id) REFERENCES yandex_subscriptions(id);


--
-- Name: yandex_subscriptions_query_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_subscriptions
    ADD CONSTRAINT yandex_subscriptions_query_id_fkey FOREIGN KEY (query_id) REFERENCES queries(id);


--
-- Name: yandex_subscriptions_yandex_region_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_subscriptions
    ADD CONSTRAINT yandex_subscriptions_yandex_region_id_fkey FOREIGN KEY (yandex_region_id) REFERENCES yandex_regions(id);


--
-- Name: yandex_view_entries_view_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_view_entries
    ADD CONSTRAINT yandex_view_entries_view_id_fkey FOREIGN KEY (view_id) REFERENCES views(id);


--
-- Name: yandex_view_entries_yandex_resources_subscriptions_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_view_entries
    ADD CONSTRAINT yandex_view_entries_yandex_resources_subscriptions_id_fkey FOREIGN KEY (yandex_resources_subscriptions_id) REFERENCES yandex_resources_subscriptions(id);


--
-- Name: yandex_wordstat_yandex_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: monitoringengine
--

ALTER TABLE ONLY yandex_wordstat
    ADD CONSTRAINT yandex_wordstat_yandex_subscription_id_fkey FOREIGN KEY (yandex_subscription_id) REFERENCES yandex_subscriptions(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

