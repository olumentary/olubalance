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
    credit_limit numeric
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
    category character varying NOT NULL,
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
    next_occurrence_month integer
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
    bill_transaction_batch_id bigint
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
    default_account_id bigint
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
-- Name: bill_transaction_batches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bill_transaction_batches ALTER COLUMN id SET DEFAULT nextval('public.bill_transaction_batches_id_seq'::regclass);


--
-- Name: bills id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bills ALTER COLUMN id SET DEFAULT nextval('public.bills_id_seq'::regclass);


--
-- Name: documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents ALTER COLUMN id SET DEFAULT nextval('public.documents_id_seq'::regclass);


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
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


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
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_accounts_on_account_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_account_type ON public.accounts USING btree (account_type);


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
-- Name: index_transactions_on_counterpart_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_counterpart_transaction_id ON public.transactions USING btree (counterpart_transaction_id);


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
-- Name: stashes fk_rails_5e3266c16e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stashes
    ADD CONSTRAINT fk_rails_5e3266c16e FOREIGN KEY (account_id) REFERENCES public.accounts(id);


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
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: accounts fk_rails_b1e30bebc8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT fk_rails_b1e30bebc8 FOREIGN KEY (user_id) REFERENCES public.users(id);


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
('20251211193000'),
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

