SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: account_types; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.account_types AS ENUM (
    'checking',
    'savings',
    'credit',
    'cash'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id bigint NOT NULL,
    name character varying,
    starting_balance numeric,
    current_balance numeric,
    user_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    last_four character varying,
    active boolean DEFAULT true,
    account_type public.account_types DEFAULT 'checking'::public.account_types,
    interest_rate numeric,
    credit_limit numeric,
    statement_day integer,
    last_interest_charged_on date,
    last_transaction_on date
);


--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp without time zone NOT NULL,
    service_name character varying NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: authenticators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.authenticators (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    nickname character varying NOT NULL,
    otp_secret character varying NOT NULL,
    consumed_timestep integer,
    last_used_at timestamp(6) without time zone,
    confirmed_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: authenticators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.authenticators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: authenticators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.authenticators_id_seq OWNED BY public.authenticators.id;


--
-- Name: bill_transaction_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bill_transaction_batches (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    reference character varying NOT NULL,
    period_month date,
    transactions_count integer DEFAULT 0 NOT NULL,
    total_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    range_start_date date,
    range_end_date date
);


--
-- Name: bill_transaction_batches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bill_transaction_batches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bill_transaction_batches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bill_transaction_batches_id_seq OWNED BY public.bill_transaction_batches.id;


--
-- Name: bills; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bills (
    id bigint NOT NULL,
    bill_type character varying NOT NULL,
    description character varying NOT NULL,
    frequency character varying DEFAULT 'monthly'::character varying NOT NULL,
    day_of_month integer NOT NULL,
    amount numeric(12,2) NOT NULL,
    notes text,
    account_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    biweekly_mode character varying,
    second_day_of_month integer,
    biweekly_anchor_weekday integer,
    biweekly_anchor_date date,
    next_occurrence_month integer,
    category_id bigint
);


--
-- Name: bills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bills_id_seq OWNED BY public.bills.id;


--
-- Name: blazer_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blazer_audits (
    id bigint NOT NULL,
    user_id bigint,
    query_id bigint,
    statement text,
    data_source character varying,
    created_at timestamp(6) without time zone
);


--
-- Name: blazer_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blazer_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blazer_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blazer_audits_id_seq OWNED BY public.blazer_audits.id;


--
-- Name: blazer_checks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blazer_checks (
    id bigint NOT NULL,
    creator_id bigint,
    query_id bigint,
    state character varying,
    schedule character varying,
    emails text,
    slack_channels text,
    check_type character varying,
    message text,
    last_run_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: blazer_checks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blazer_checks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blazer_checks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blazer_checks_id_seq OWNED BY public.blazer_checks.id;


--
-- Name: blazer_dashboard_queries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blazer_dashboard_queries (
    id bigint NOT NULL,
    dashboard_id bigint,
    query_id bigint,
    "position" integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: blazer_dashboard_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blazer_dashboard_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blazer_dashboard_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blazer_dashboard_queries_id_seq OWNED BY public.blazer_dashboard_queries.id;


--
-- Name: blazer_dashboards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blazer_dashboards (
    id bigint NOT NULL,
    creator_id bigint,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: blazer_dashboards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blazer_dashboards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blazer_dashboards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blazer_dashboards_id_seq OWNED BY public.blazer_dashboards.id;


--
-- Name: blazer_queries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blazer_queries (
    id bigint NOT NULL,
    creator_id bigint,
    name character varying,
    description text,
    statement text,
    data_source character varying,
    status character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: blazer_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blazer_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blazer_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blazer_queries_id_seq OWNED BY public.blazer_queries.id;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    name character varying NOT NULL,
    kind integer DEFAULT 0 NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: category_lookups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_lookups (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    category_id bigint NOT NULL,
    description_norm text NOT NULL,
    usage_count integer DEFAULT 1 NOT NULL,
    last_used_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: category_lookups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_lookups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_lookups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_lookups_id_seq OWNED BY public.category_lookups.id;


--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    id bigint NOT NULL,
    attachable_type character varying NOT NULL,
    attachable_id bigint NOT NULL,
    category character varying,
    tax_year integer,
    document_date date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    description text
);


--
-- Name: documents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.documents_id_seq OWNED BY public.documents.id;


--
-- Name: hidden_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hidden_categories (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    category_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: hidden_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hidden_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hidden_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hidden_categories_id_seq OWNED BY public.hidden_categories.id;


--
-- Name: login_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.login_events (
    id bigint NOT NULL,
    user_id bigint,
    email_attempted character varying,
    ip inet,
    user_agent character varying,
    event_type character varying NOT NULL,
    reason character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: login_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.login_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: login_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.login_events_id_seq OWNED BY public.login_events.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: stash_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stash_entries (
    id bigint NOT NULL,
    stash_entry_date timestamp without time zone,
    description character varying,
    amount numeric,
    stash_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    transaction_id bigint
);


--
-- Name: stash_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stash_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stash_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stash_entries_id_seq OWNED BY public.stash_entries.id;


--
-- Name: stashes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stashes (
    id bigint NOT NULL,
    name character varying,
    description character varying,
    balance numeric DEFAULT 0.0,
    goal numeric,
    active boolean DEFAULT true,
    account_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: stashes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stashes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stashes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stashes_id_seq OWNED BY public.stashes.id;


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transactions (
    id bigint NOT NULL,
    trx_date date,
    description character varying,
    amount numeric,
    account_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    memo character varying,
    pending boolean DEFAULT false,
    locked boolean DEFAULT false,
    transfer boolean DEFAULT false,
    quick_receipt boolean,
    counterpart_transaction_id bigint,
    batch_reference character varying,
    bill_transaction_batch_id bigint,
    category_id bigint
);


--
-- Name: transaction_balances; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.transaction_balances AS
 SELECT id AS transaction_id,
    sum(amount) OVER (PARTITION BY account_id ORDER BY pending, trx_date, id) AS running_balance
   FROM public.transactions;


--
-- Name: transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transactions_id_seq OWNED BY public.transactions.id;


--
-- Name: trusted_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trusted_devices (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token_digest character varying NOT NULL,
    user_agent character varying,
    ip inet,
    last_seen_at timestamp(6) without time zone,
    expires_at timestamp(6) without time zone NOT NULL,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: trusted_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trusted_devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trusted_devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trusted_devices_id_seq OWNED BY public.trusted_devices.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip inet,
    last_sign_in_ip inet,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    first_name character varying,
    last_name character varying,
    timezone character varying,
    confirmation_token character varying,
    confirmed_at timestamp without time zone,
    confirmation_sent_at timestamp without time zone,
    unconfirmed_email character varying,
    default_account_id bigint,
    failed_attempts integer DEFAULT 0 NOT NULL,
    unlock_token character varying,
    locked_at timestamp(6) without time zone,
    otp_backup_codes character varying[] DEFAULT '{}'::character varying[],
    admin boolean DEFAULT false NOT NULL,
    current_streak_weeks integer DEFAULT 0 CONSTRAINT users_current_streak_days_not_null NOT NULL,
    longest_streak_weeks integer DEFAULT 0 CONSTRAINT users_longest_streak_days_not_null NOT NULL,
    streak_last_evaluated_on date
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: authenticators id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authenticators ALTER COLUMN id SET DEFAULT nextval('public.authenticators_id_seq'::regclass);


--
-- Name: bill_transaction_batches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bill_transaction_batches ALTER COLUMN id SET DEFAULT nextval('public.bill_transaction_batches_id_seq'::regclass);


--
-- Name: bills id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bills ALTER COLUMN id SET DEFAULT nextval('public.bills_id_seq'::regclass);


--
-- Name: blazer_audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_audits ALTER COLUMN id SET DEFAULT nextval('public.blazer_audits_id_seq'::regclass);


--
-- Name: blazer_checks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_checks ALTER COLUMN id SET DEFAULT nextval('public.blazer_checks_id_seq'::regclass);


--
-- Name: blazer_dashboard_queries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_dashboard_queries ALTER COLUMN id SET DEFAULT nextval('public.blazer_dashboard_queries_id_seq'::regclass);


--
-- Name: blazer_dashboards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_dashboards ALTER COLUMN id SET DEFAULT nextval('public.blazer_dashboards_id_seq'::regclass);


--
-- Name: blazer_queries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_queries ALTER COLUMN id SET DEFAULT nextval('public.blazer_queries_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: category_lookups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_lookups ALTER COLUMN id SET DEFAULT nextval('public.category_lookups_id_seq'::regclass);


--
-- Name: documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents ALTER COLUMN id SET DEFAULT nextval('public.documents_id_seq'::regclass);


--
-- Name: hidden_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_categories ALTER COLUMN id SET DEFAULT nextval('public.hidden_categories_id_seq'::regclass);


--
-- Name: login_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_events ALTER COLUMN id SET DEFAULT nextval('public.login_events_id_seq'::regclass);


--
-- Name: stash_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_entries ALTER COLUMN id SET DEFAULT nextval('public.stash_entries_id_seq'::regclass);


--
-- Name: stashes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stashes ALTER COLUMN id SET DEFAULT nextval('public.stashes_id_seq'::regclass);


--
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.transactions_id_seq'::regclass);


--
-- Name: trusted_devices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trusted_devices ALTER COLUMN id SET DEFAULT nextval('public.trusted_devices_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: authenticators authenticators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authenticators
    ADD CONSTRAINT authenticators_pkey PRIMARY KEY (id);


--
-- Name: bill_transaction_batches bill_transaction_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bill_transaction_batches
    ADD CONSTRAINT bill_transaction_batches_pkey PRIMARY KEY (id);


--
-- Name: bills bills_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bills
    ADD CONSTRAINT bills_pkey PRIMARY KEY (id);


--
-- Name: blazer_audits blazer_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_audits
    ADD CONSTRAINT blazer_audits_pkey PRIMARY KEY (id);


--
-- Name: blazer_checks blazer_checks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_checks
    ADD CONSTRAINT blazer_checks_pkey PRIMARY KEY (id);


--
-- Name: blazer_dashboard_queries blazer_dashboard_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_dashboard_queries
    ADD CONSTRAINT blazer_dashboard_queries_pkey PRIMARY KEY (id);


--
-- Name: blazer_dashboards blazer_dashboards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_dashboards
    ADD CONSTRAINT blazer_dashboards_pkey PRIMARY KEY (id);


--
-- Name: blazer_queries blazer_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_queries
    ADD CONSTRAINT blazer_queries_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: category_lookups category_lookups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_lookups
    ADD CONSTRAINT category_lookups_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: hidden_categories hidden_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_categories
    ADD CONSTRAINT hidden_categories_pkey PRIMARY KEY (id);


--
-- Name: login_events login_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_events
    ADD CONSTRAINT login_events_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: stash_entries stash_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_entries
    ADD CONSTRAINT stash_entries_pkey PRIMARY KEY (id);


--
-- Name: stashes stashes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stashes
    ADD CONSTRAINT stashes_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: trusted_devices trusted_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trusted_devices
    ADD CONSTRAINT trusted_devices_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_accounts_on_account_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_account_type ON public.accounts USING btree (account_type);


--
-- Name: index_accounts_on_last_transaction_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_last_transaction_on ON public.accounts USING btree (last_transaction_on);


--
-- Name: index_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_user_id ON public.accounts USING btree (user_id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_authenticators_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_authenticators_on_user_id ON public.authenticators USING btree (user_id);


--
-- Name: index_authenticators_on_user_id_and_nickname; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_authenticators_on_user_id_and_nickname ON public.authenticators USING btree (user_id, nickname);


--
-- Name: index_batches_on_user_and_range; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_batches_on_user_and_range ON public.bill_transaction_batches USING btree (user_id, range_start_date, range_end_date);


--
-- Name: index_bill_transaction_batches_on_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bill_transaction_batches_on_reference ON public.bill_transaction_batches USING btree (reference);


--
-- Name: index_bill_transaction_batches_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bill_transaction_batches_on_user_id ON public.bill_transaction_batches USING btree (user_id);


--
-- Name: index_bill_transaction_batches_on_user_id_and_period_month; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bill_transaction_batches_on_user_id_and_period_month ON public.bill_transaction_batches USING btree (user_id, period_month);


--
-- Name: index_bills_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bills_on_account_id ON public.bills USING btree (account_id);


--
-- Name: index_bills_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bills_on_category_id ON public.bills USING btree (category_id);


--
-- Name: index_bills_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bills_on_user_id ON public.bills USING btree (user_id);


--
-- Name: index_bills_on_user_id_and_bill_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bills_on_user_id_and_bill_type ON public.bills USING btree (user_id, bill_type);


--
-- Name: index_bills_on_user_id_and_day_of_month; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bills_on_user_id_and_day_of_month ON public.bills USING btree (user_id, day_of_month);


--
-- Name: index_bills_on_user_id_and_frequency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bills_on_user_id_and_frequency ON public.bills USING btree (user_id, frequency);


--
-- Name: index_blazer_audits_on_query_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_audits_on_query_id ON public.blazer_audits USING btree (query_id);


--
-- Name: index_blazer_audits_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_audits_on_user_id ON public.blazer_audits USING btree (user_id);


--
-- Name: index_blazer_checks_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_checks_on_creator_id ON public.blazer_checks USING btree (creator_id);


--
-- Name: index_blazer_checks_on_query_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_checks_on_query_id ON public.blazer_checks USING btree (query_id);


--
-- Name: index_blazer_dashboard_queries_on_dashboard_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_dashboard_queries_on_dashboard_id ON public.blazer_dashboard_queries USING btree (dashboard_id);


--
-- Name: index_blazer_dashboard_queries_on_query_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_dashboard_queries_on_query_id ON public.blazer_dashboard_queries USING btree (query_id);


--
-- Name: index_blazer_dashboards_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_dashboards_on_creator_id ON public.blazer_dashboards USING btree (creator_id);


--
-- Name: index_blazer_queries_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_queries_on_creator_id ON public.blazer_queries USING btree (creator_id);


--
-- Name: index_categories_on_user_and_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_user_and_lower_name ON public.categories USING btree (lower((name)::text), COALESCE(user_id, (0)::bigint));


--
-- Name: index_categories_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_user_id ON public.categories USING btree (user_id);


--
-- Name: index_category_lookups_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_lookups_on_category_id ON public.category_lookups USING btree (category_id);


--
-- Name: index_category_lookups_on_description_norm_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_lookups_on_description_norm_trgm ON public.category_lookups USING gin (description_norm public.gin_trgm_ops);


--
-- Name: index_category_lookups_on_user_and_description_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_category_lookups_on_user_and_description_norm ON public.category_lookups USING btree (user_id, description_norm);


--
-- Name: index_category_lookups_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_lookups_on_user_id ON public.category_lookups USING btree (user_id);


--
-- Name: index_documents_on_attachable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_attachable ON public.documents USING btree (attachable_type, attachable_id);


--
-- Name: index_documents_on_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_category ON public.documents USING btree (category);


--
-- Name: index_documents_on_document_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_document_date ON public.documents USING btree (document_date);


--
-- Name: index_documents_on_tax_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_tax_year ON public.documents USING btree (tax_year);


--
-- Name: index_hidden_categories_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_hidden_categories_on_category_id ON public.hidden_categories USING btree (category_id);


--
-- Name: index_hidden_categories_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_hidden_categories_on_user_id ON public.hidden_categories USING btree (user_id);


--
-- Name: index_hidden_categories_on_user_id_and_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_hidden_categories_on_user_id_and_category_id ON public.hidden_categories USING btree (user_id, category_id);


--
-- Name: index_login_events_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_login_events_on_created_at ON public.login_events USING btree (created_at DESC);


--
-- Name: index_login_events_on_email_attempted_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_login_events_on_email_attempted_and_created_at ON public.login_events USING btree (email_attempted, created_at);


--
-- Name: index_login_events_on_event_type_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_login_events_on_event_type_and_created_at ON public.login_events USING btree (event_type, created_at);


--
-- Name: index_login_events_on_ip_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_login_events_on_ip_and_created_at ON public.login_events USING btree (ip, created_at);


--
-- Name: index_login_events_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_login_events_on_user_id ON public.login_events USING btree (user_id);


--
-- Name: index_stash_entries_on_stash_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stash_entries_on_stash_id ON public.stash_entries USING btree (stash_id);


--
-- Name: index_stash_entries_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stash_entries_on_transaction_id ON public.stash_entries USING btree (transaction_id);


--
-- Name: index_stashes_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stashes_on_account_id ON public.stashes USING btree (account_id);


--
-- Name: index_transactions_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_account_id ON public.transactions USING btree (account_id);


--
-- Name: index_transactions_on_batch_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_batch_reference ON public.transactions USING btree (batch_reference);


--
-- Name: index_transactions_on_bill_transaction_batch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_bill_transaction_batch_id ON public.transactions USING btree (bill_transaction_batch_id);


--
-- Name: index_transactions_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_category_id ON public.transactions USING btree (category_id);


--
-- Name: index_transactions_on_counterpart_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_counterpart_transaction_id ON public.transactions USING btree (counterpart_transaction_id);


--
-- Name: index_trusted_devices_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trusted_devices_on_expires_at ON public.trusted_devices USING btree (expires_at);


--
-- Name: index_trusted_devices_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_trusted_devices_on_token_digest ON public.trusted_devices USING btree (token_digest);


--
-- Name: index_trusted_devices_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trusted_devices_on_user_id ON public.trusted_devices USING btree (user_id);


--
-- Name: index_users_on_admin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_admin ON public.users USING btree (admin) WHERE (admin = true);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_confirmation_token ON public.users USING btree (confirmation_token);


--
-- Name: index_users_on_default_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_default_account_id ON public.users USING btree (default_account_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_unlock_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_unlock_token ON public.users USING btree (unlock_token);


--
-- Name: transaction_balances tb_del_protect; Type: RULE; Schema: public; Owner: -
--

CREATE RULE tb_del_protect AS
    ON DELETE TO public.transaction_balances DO INSTEAD NOTHING;


--
-- Name: transaction_balances tb_ins_protect; Type: RULE; Schema: public; Owner: -
--

CREATE RULE tb_ins_protect AS
    ON INSERT TO public.transaction_balances DO INSTEAD NOTHING;


--
-- Name: transaction_balances tb_upd_protect; Type: RULE; Schema: public; Owner: -
--

CREATE RULE tb_upd_protect AS
    ON UPDATE TO public.transaction_balances DO INSTEAD NOTHING;


--
-- Name: transactions fk_rails_01f020e267; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_01f020e267 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: transactions fk_rails_0ea2ad3927; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_0ea2ad3927 FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL;


--
-- Name: bill_transaction_batches fk_rails_16c90372dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bill_transaction_batches
    ADD CONSTRAINT fk_rails_16c90372dc FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: stash_entries fk_rails_44f90c5488; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_entries
    ADD CONSTRAINT fk_rails_44f90c5488 FOREIGN KEY (transaction_id) REFERENCES public.transactions(id);


--
-- Name: hidden_categories fk_rails_450714abe8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_categories
    ADD CONSTRAINT fk_rails_450714abe8 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: bills fk_rails_497ba0b958; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bills
    ADD CONSTRAINT fk_rails_497ba0b958 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: category_lookups fk_rails_5566223128; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_lookups
    ADD CONSTRAINT fk_rails_5566223128 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: stashes fk_rails_5e3266c16e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stashes
    ADD CONSTRAINT fk_rails_5e3266c16e FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: category_lookups fk_rails_608d7393f1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_lookups
    ADD CONSTRAINT fk_rails_608d7393f1 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: users fk_rails_68e8c5de71; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_68e8c5de71 FOREIGN KEY (default_account_id) REFERENCES public.accounts(id);


--
-- Name: stash_entries fk_rails_6ebf595ff0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_entries
    ADD CONSTRAINT fk_rails_6ebf595ff0 FOREIGN KEY (stash_id) REFERENCES public.stashes(id);


--
-- Name: bills fk_rails_79e8aa9e27; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bills
    ADD CONSTRAINT fk_rails_79e8aa9e27 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: hidden_categories fk_rails_8cc52c7c0b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_categories
    ADD CONSTRAINT fk_rails_8cc52c7c0b FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: trusted_devices fk_rails_96c1dacf00; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trusted_devices
    ADD CONSTRAINT fk_rails_96c1dacf00 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: login_events fk_rails_9b3abaedfe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_events
    ADD CONSTRAINT fk_rails_9b3abaedfe FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: accounts fk_rails_b1e30bebc8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT fk_rails_b1e30bebc8 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: authenticators fk_rails_b3092b2ea8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authenticators
    ADD CONSTRAINT fk_rails_b3092b2ea8 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: categories fk_rails_b8e2f7adfc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT fk_rails_b8e2f7adfc FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transactions fk_rails_c318c1af13; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_c318c1af13 FOREIGN KEY (counterpart_transaction_id) REFERENCES public.transactions(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: transactions fk_rails_f0365210d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_f0365210d9 FOREIGN KEY (bill_transaction_batch_id) REFERENCES public.bill_transaction_batches(id);


--
-- Name: bills fk_rails_f5fcc78f42; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bills
    ADD CONSTRAINT fk_rails_f5fcc78f42 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260521130000'),
('20260521120100'),
('20260521120000'),
('20260520220209'),
('20260520164549'),
('20260520164411'),
('20260520000915'),
('20260520000838'),
('20260519124420'),
('20260519124413'),
('20260518142810'),
('20260518142805'),
('20260518142800'),
('20260518142755'),
('20251226000001'),
('20251211193000'),
('20251211140000'),
('20251211130000'),
('20251211120000'),
('20251209131000'),
('20251209120000'),
('20251208120000'),
('20251013201933'),
('20250910233755'),
('20250619000235'),
('20250120000004'),
('20250120000003'),
('20250120000002'),
('20250120000001'),
('20250120000000'),
('20240125144637'),
('20210104203329'),
('20210104203328'),
('20210102150348'),
('20201230210944'),
('20201230210340'),
('20200807000110'),
('20200623012351'),
('20200128211634'),
('20191227150641'),
('20191220011006'),
('20191219035136'),
('20191102124707'),
('20190802193709'),
('20190802191418'),
('20190626011950'),
('20181009135959'),
('20180926184009'),
('20180819191749'),
('20180723221149'),
('20180327154809'),
('20180327154122'),
('20180321221542'),
('20180319220307'),
('20180130031520'),
('20180130031515'),
('20180130031514');

