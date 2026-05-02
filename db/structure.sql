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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    parent_account_id bigint,
    account_category integer NOT NULL,
    account_structure integer NOT NULL,
    name text NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    icon_key integer NOT NULL,
    color_hex text NOT NULL,
    currency_code text NOT NULL,
    balance_cents integer DEFAULT 0 NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    discarded_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT accounts_category_valid CHECK ((account_category = ANY (ARRAY[1, 2, 3, 4, 5, 6, 7, 8, 9]))),
    CONSTRAINT accounts_color_hex_length CHECK ((char_length(color_hex) = 6)),
    CONSTRAINT accounts_currency_code_length CHECK ((char_length(currency_code) = 3)),
    CONSTRAINT accounts_parent_not_self CHECK (((parent_account_id IS NULL) OR (parent_account_id <> id))),
    CONSTRAINT accounts_structure_valid CHECK ((account_structure = ANY (ARRAY[1, 2])))
);


--
-- Name: TABLE accounts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.accounts IS 'User-owned ledger accounts';


--
-- Name: COLUMN accounts.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.user_id IS 'Owner of this account';


--
-- Name: COLUMN accounts.parent_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.parent_account_id IS 'Parent account for two-level account hierarchies';


--
-- Name: COLUMN accounts.account_category; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.account_category IS 'Account category code from ezBookkeeping';


--
-- Name: COLUMN accounts.account_structure; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.account_structure IS 'Account structure code: single or multi-sub-account';


--
-- Name: COLUMN accounts.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.name IS 'Human-readable account name';


--
-- Name: COLUMN accounts.display_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.display_order IS 'User-controlled display order';


--
-- Name: COLUMN accounts.icon_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.icon_key IS 'Icon identifier from the account icon catalog';


--
-- Name: COLUMN accounts.color_hex; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.color_hex IS 'Six-character RGB hex color without #';


--
-- Name: COLUMN accounts.currency_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.currency_code IS 'ISO 4217 currency code';


--
-- Name: COLUMN accounts.balance_cents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.balance_cents IS 'Current account balance in cents';


--
-- Name: COLUMN accounts.comment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.comment IS 'Optional user note';


--
-- Name: COLUMN accounts.hidden; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.hidden IS 'Whether the account is hidden in normal lists';


--
-- Name: COLUMN accounts.discarded_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.accounts.discarded_at IS 'Soft deletion timestamp';


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
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: transaction_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction_categories (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    parent_category_id bigint,
    category_type integer NOT NULL,
    name text NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    icon_key integer NOT NULL,
    color_hex text NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    discarded_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT transaction_categories_color_hex_length CHECK ((char_length(color_hex) = 6)),
    CONSTRAINT transaction_categories_parent_not_self CHECK (((parent_category_id IS NULL) OR (parent_category_id <> id))),
    CONSTRAINT transaction_categories_type_valid CHECK ((category_type = ANY (ARRAY[1, 2, 3])))
);


--
-- Name: TABLE transaction_categories; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.transaction_categories IS 'User-owned transaction categories';


--
-- Name: COLUMN transaction_categories.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_categories.user_id IS 'Owner of this category';


--
-- Name: COLUMN transaction_categories.parent_category_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_categories.parent_category_id IS 'Parent category for two-level category hierarchies';


--
-- Name: COLUMN transaction_categories.category_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_categories.category_type IS 'Category type code: income, expense, or transfer';


--
-- Name: COLUMN transaction_categories.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_categories.name IS 'Human-readable category name';


--
-- Name: COLUMN transaction_categories.display_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_categories.display_order IS 'User-controlled display order';


--
-- Name: COLUMN transaction_categories.icon_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_categories.icon_key IS 'Icon identifier from the category icon catalog';


--
-- Name: COLUMN transaction_categories.color_hex; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_categories.color_hex IS 'Six-character RGB hex color without #';


--
-- Name: COLUMN transaction_categories.hidden; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_categories.hidden IS 'Whether the category is hidden in normal lists';


--
-- Name: COLUMN transaction_categories.comment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_categories.comment IS 'Optional user note';


--
-- Name: COLUMN transaction_categories.discarded_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_categories.discarded_at IS 'Soft deletion timestamp';


--
-- Name: transaction_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transaction_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transaction_categories_id_seq OWNED BY public.transaction_categories.id;


--
-- Name: transaction_tag_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction_tag_groups (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    name text NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    discarded_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: TABLE transaction_tag_groups; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.transaction_tag_groups IS 'User-owned transaction tag groups';


--
-- Name: COLUMN transaction_tag_groups.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_tag_groups.user_id IS 'Owner of this tag group';


--
-- Name: COLUMN transaction_tag_groups.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_tag_groups.name IS 'Human-readable tag group name';


--
-- Name: COLUMN transaction_tag_groups.display_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_tag_groups.display_order IS 'User-controlled display order';


--
-- Name: COLUMN transaction_tag_groups.discarded_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_tag_groups.discarded_at IS 'Soft deletion timestamp';


--
-- Name: transaction_tag_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transaction_tag_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_tag_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transaction_tag_groups_id_seq OWNED BY public.transaction_tag_groups.id;


--
-- Name: transaction_taggings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction_taggings (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    transaction_id bigint NOT NULL,
    transaction_tag_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: TABLE transaction_taggings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.transaction_taggings IS 'Join table between transactions and tags';


--
-- Name: COLUMN transaction_taggings.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_taggings.user_id IS 'Owner of this tagging';


--
-- Name: COLUMN transaction_taggings.transaction_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_taggings.transaction_id IS 'Tagged transaction';


--
-- Name: COLUMN transaction_taggings.transaction_tag_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_taggings.transaction_tag_id IS 'Applied transaction tag';


--
-- Name: transaction_taggings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transaction_taggings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_taggings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transaction_taggings_id_seq OWNED BY public.transaction_taggings.id;


--
-- Name: transaction_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction_tags (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    transaction_tag_group_id bigint,
    name text NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    discarded_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: TABLE transaction_tags; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.transaction_tags IS 'User-owned transaction tags';


--
-- Name: COLUMN transaction_tags.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_tags.user_id IS 'Owner of this tag';


--
-- Name: COLUMN transaction_tags.transaction_tag_group_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_tags.transaction_tag_group_id IS 'Optional tag group';


--
-- Name: COLUMN transaction_tags.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_tags.name IS 'Human-readable tag name';


--
-- Name: COLUMN transaction_tags.display_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_tags.display_order IS 'User-controlled display order';


--
-- Name: COLUMN transaction_tags.hidden; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_tags.hidden IS 'Whether the tag is hidden in normal lists';


--
-- Name: COLUMN transaction_tags.discarded_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_tags.discarded_at IS 'Soft deletion timestamp';


--
-- Name: transaction_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transaction_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transaction_tags_id_seq OWNED BY public.transaction_tags.id;


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transactions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    account_id bigint NOT NULL,
    destination_account_id bigint,
    transaction_kind integer NOT NULL,
    transacted_at timestamp(6) with time zone NOT NULL,
    timezone_utc_offset_minutes integer DEFAULT 0 NOT NULL,
    source_amount_cents integer NOT NULL,
    destination_amount_cents integer DEFAULT 0 NOT NULL,
    hide_amount boolean DEFAULT false NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    discarded_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT transactions_destination_amount_range CHECK (((destination_amount_cents >= '-99999999999'::bigint) AND (destination_amount_cents <= '99999999999'::bigint))),
    CONSTRAINT transactions_destination_differs_from_source CHECK (((destination_account_id IS NULL) OR (destination_account_id <> account_id))),
    CONSTRAINT transactions_kind_valid CHECK ((transaction_kind = ANY (ARRAY[1, 2, 3, 4]))),
    CONSTRAINT transactions_non_transfer_has_no_destination CHECK (((transaction_kind = 4) OR (destination_account_id IS NULL))),
    CONSTRAINT transactions_source_amount_range CHECK (((source_amount_cents >= '-99999999999'::bigint) AND (source_amount_cents <= '99999999999'::bigint))),
    CONSTRAINT transactions_transfer_destination_required CHECK (((transaction_kind <> 4) OR (destination_account_id IS NOT NULL)))
);


--
-- Name: TABLE transactions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.transactions IS 'User-owned ledger transactions';


--
-- Name: COLUMN transactions.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transactions.user_id IS 'Owner of this transaction';


--
-- Name: COLUMN transactions.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transactions.account_id IS 'Source account affected by this transaction';


--
-- Name: COLUMN transactions.destination_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transactions.destination_account_id IS 'Destination account for transfers';


--
-- Name: COLUMN transactions.transaction_kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transactions.transaction_kind IS 'Transaction kind code: balance adjustment, income, expense, transfer';


--
-- Name: COLUMN transactions.transacted_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transactions.transacted_at IS 'User-entered transaction timestamp';


--
-- Name: COLUMN transactions.timezone_utc_offset_minutes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transactions.timezone_utc_offset_minutes IS 'User timezone offset at transaction time';


--
-- Name: COLUMN transactions.source_amount_cents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transactions.source_amount_cents IS 'Source account amount or balance adjustment delta in cents';


--
-- Name: COLUMN transactions.destination_amount_cents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transactions.destination_amount_cents IS 'Destination account amount for transfers in cents';


--
-- Name: COLUMN transactions.hide_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transactions.hide_amount IS 'Whether amount should be hidden in normal UI';


--
-- Name: COLUMN transactions.comment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transactions.comment IS 'Optional user note';


--
-- Name: COLUMN transactions.discarded_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transactions.discarded_at IS 'Soft deletion timestamp';


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
    reset_password_sent_at timestamp(6) with time zone,
    remember_created_at timestamp(6) with time zone,
    first_name character varying,
    last_name character varying,
    provider character varying,
    uid character varying,
    discarded_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
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
-- Name: transaction_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_categories ALTER COLUMN id SET DEFAULT nextval('public.transaction_categories_id_seq'::regclass);


--
-- Name: transaction_tag_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_tag_groups ALTER COLUMN id SET DEFAULT nextval('public.transaction_tag_groups_id_seq'::regclass);


--
-- Name: transaction_taggings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_taggings ALTER COLUMN id SET DEFAULT nextval('public.transaction_taggings_id_seq'::regclass);


--
-- Name: transaction_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_tags ALTER COLUMN id SET DEFAULT nextval('public.transaction_tags_id_seq'::regclass);


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
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: transaction_categories transaction_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_categories
    ADD CONSTRAINT transaction_categories_pkey PRIMARY KEY (id);


--
-- Name: transaction_tag_groups transaction_tag_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_tag_groups
    ADD CONSTRAINT transaction_tag_groups_pkey PRIMARY KEY (id);


--
-- Name: transaction_taggings transaction_taggings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_taggings
    ADD CONSTRAINT transaction_taggings_pkey PRIMARY KEY (id);


--
-- Name: transaction_tags transaction_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_tags
    ADD CONSTRAINT transaction_tags_pkey PRIMARY KEY (id);


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
-- Name: index_accounts_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_discarded_at ON public.accounts USING btree (discarded_at);


--
-- Name: index_accounts_on_owner_parent_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_owner_parent_order ON public.accounts USING btree (user_id, parent_account_id, display_order);


--
-- Name: index_accounts_on_parent_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_parent_account_id ON public.accounts USING btree (parent_account_id);


--
-- Name: index_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_accounts_on_user_id ON public.accounts USING btree (user_id);


--
-- Name: index_transaction_categories_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_categories_on_discarded_at ON public.transaction_categories USING btree (discarded_at);


--
-- Name: index_transaction_categories_on_owner_type_parent_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_categories_on_owner_type_parent_order ON public.transaction_categories USING btree (user_id, category_type, parent_category_id, display_order);


--
-- Name: index_transaction_categories_on_parent_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_categories_on_parent_category_id ON public.transaction_categories USING btree (parent_category_id);


--
-- Name: index_transaction_categories_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_categories_on_user_id ON public.transaction_categories USING btree (user_id);


--
-- Name: index_transaction_tag_groups_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_tag_groups_on_discarded_at ON public.transaction_tag_groups USING btree (discarded_at);


--
-- Name: index_transaction_tag_groups_on_owner_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_tag_groups_on_owner_order ON public.transaction_tag_groups USING btree (user_id, display_order);


--
-- Name: index_transaction_tag_groups_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_tag_groups_on_user_id ON public.transaction_tag_groups USING btree (user_id);


--
-- Name: index_transaction_taggings_on_transaction_and_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_transaction_taggings_on_transaction_and_tag ON public.transaction_taggings USING btree (transaction_id, transaction_tag_id);


--
-- Name: index_transaction_taggings_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_taggings_on_transaction_id ON public.transaction_taggings USING btree (transaction_id);


--
-- Name: index_transaction_taggings_on_transaction_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_taggings_on_transaction_tag_id ON public.transaction_taggings USING btree (transaction_tag_id);


--
-- Name: index_transaction_taggings_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_taggings_on_user_id ON public.transaction_taggings USING btree (user_id);


--
-- Name: index_transaction_tags_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_tags_on_discarded_at ON public.transaction_tags USING btree (discarded_at);


--
-- Name: index_transaction_tags_on_owner_group_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_tags_on_owner_group_order ON public.transaction_tags USING btree (user_id, transaction_tag_group_id, display_order);


--
-- Name: index_transaction_tags_on_transaction_tag_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_tags_on_transaction_tag_group_id ON public.transaction_tags USING btree (transaction_tag_group_id);


--
-- Name: index_transaction_tags_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_tags_on_user_id ON public.transaction_tags USING btree (user_id);


--
-- Name: index_transactions_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_account_id ON public.transactions USING btree (account_id);


--
-- Name: index_transactions_on_destination_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_destination_account_id ON public.transactions USING btree (destination_account_id);


--
-- Name: index_transactions_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_discarded_at ON public.transactions USING btree (discarded_at);


--
-- Name: index_transactions_on_owner_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_owner_time ON public.transactions USING btree (user_id, transacted_at);


--
-- Name: index_transactions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_user_id ON public.transactions USING btree (user_id);


--
-- Name: index_users_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_discarded_at ON public.users USING btree (discarded_at);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_provider_and_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_provider_and_uid ON public.users USING btree (provider, uid);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: transactions fk_rails_01f020e267; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_01f020e267 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: transaction_categories fk_rails_058bfd7845; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_categories
    ADD CONSTRAINT fk_rails_058bfd7845 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transaction_categories fk_rails_4b9fac99aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_categories
    ADD CONSTRAINT fk_rails_4b9fac99aa FOREIGN KEY (parent_category_id) REFERENCES public.transaction_categories(id);


--
-- Name: transactions fk_rails_77364e6416; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_77364e6416 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transaction_taggings fk_rails_7905dab616; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_taggings
    ADD CONSTRAINT fk_rails_7905dab616 FOREIGN KEY (transaction_id) REFERENCES public.transactions(id);


--
-- Name: transaction_taggings fk_rails_85aa95e074; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_taggings
    ADD CONSTRAINT fk_rails_85aa95e074 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: accounts fk_rails_add3a59cd7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT fk_rails_add3a59cd7 FOREIGN KEY (parent_account_id) REFERENCES public.accounts(id);


--
-- Name: accounts fk_rails_b1e30bebc8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT fk_rails_b1e30bebc8 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transaction_tags fk_rails_d5db8ca0c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_tags
    ADD CONSTRAINT fk_rails_d5db8ca0c9 FOREIGN KEY (transaction_tag_group_id) REFERENCES public.transaction_tag_groups(id);


--
-- Name: transaction_tag_groups fk_rails_dc26ed20aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_tag_groups
    ADD CONSTRAINT fk_rails_dc26ed20aa FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transaction_tags fk_rails_e6a6340042; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_tags
    ADD CONSTRAINT fk_rails_e6a6340042 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transaction_taggings fk_rails_f277d342d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_taggings
    ADD CONSTRAINT fk_rails_f277d342d3 FOREIGN KEY (transaction_tag_id) REFERENCES public.transaction_tags(id);


--
-- Name: transactions fk_rails_f7070c25b3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_f7070c25b3 FOREIGN KEY (destination_account_id) REFERENCES public.accounts(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260503100000'),
('20260503090000'),
('20260411171621');

