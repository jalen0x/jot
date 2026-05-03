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
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL
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
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) with time zone NOT NULL
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
-- Name: api_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_tokens (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    name text NOT NULL,
    token_digest text NOT NULL,
    last_used_at timestamp(6) with time zone,
    expires_at timestamp(6) with time zone,
    discarded_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: TABLE api_tokens; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.api_tokens IS 'User-owned API token digests';


--
-- Name: COLUMN api_tokens.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.api_tokens.user_id IS 'Owner of this API token';


--
-- Name: COLUMN api_tokens.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.api_tokens.name IS 'User-facing token name';


--
-- Name: COLUMN api_tokens.token_digest; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.api_tokens.token_digest IS 'BCrypt digest of the raw token';


--
-- Name: COLUMN api_tokens.last_used_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.api_tokens.last_used_at IS 'Last successful authentication time';


--
-- Name: COLUMN api_tokens.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.api_tokens.expires_at IS 'Optional expiration time';


--
-- Name: COLUMN api_tokens.discarded_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.api_tokens.discarded_at IS 'Soft deletion timestamp';


--
-- Name: api_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_tokens_id_seq OWNED BY public.api_tokens.id;


--
-- Name: application_locks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.application_locks (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    pin_digest text NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: TABLE application_locks; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.application_locks IS 'User-owned application lock PIN digests';


--
-- Name: COLUMN application_locks.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.application_locks.user_id IS 'Owner of this application lock';


--
-- Name: COLUMN application_locks.pin_digest; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.application_locks.pin_digest IS 'BCrypt digest of the application lock PIN';


--
-- Name: application_locks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.application_locks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: application_locks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.application_locks_id_seq OWNED BY public.application_locks.id;


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
-- Name: import_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_batches (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    source_filename text DEFAULT ''::text NOT NULL,
    raw_csv text NOT NULL,
    imported_count integer DEFAULT 0 NOT NULL,
    error_message text DEFAULT ''::text NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT import_batches_status_valid CHECK ((status = ANY (ARRAY[0, 1, 2, 3])))
);


--
-- Name: TABLE import_batches; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.import_batches IS 'User-owned transaction import batches';


--
-- Name: COLUMN import_batches.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.import_batches.user_id IS 'Owner of this import batch';


--
-- Name: COLUMN import_batches.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.import_batches.status IS 'Import status code: pending, processing, imported, or failed';


--
-- Name: COLUMN import_batches.source_filename; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.import_batches.source_filename IS 'Original uploaded file name or label';


--
-- Name: COLUMN import_batches.raw_csv; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.import_batches.raw_csv IS 'Raw CSV snapshot to import';


--
-- Name: COLUMN import_batches.imported_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.import_batches.imported_count IS 'Number of imported transaction rows';


--
-- Name: COLUMN import_batches.error_message; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.import_batches.error_message IS 'User-facing import error message';


--
-- Name: import_batches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.import_batches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: import_batches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.import_batches_id_seq OWNED BY public.import_batches.id;


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
-- Name: transaction_template_taggings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction_template_taggings (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    transaction_template_id bigint NOT NULL,
    transaction_tag_id bigint NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: TABLE transaction_template_taggings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.transaction_template_taggings IS 'Join table between transaction templates and tags';


--
-- Name: COLUMN transaction_template_taggings.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_template_taggings.user_id IS 'Owner of this template tagging';


--
-- Name: COLUMN transaction_template_taggings.transaction_template_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_template_taggings.transaction_template_id IS 'Tagged transaction template';


--
-- Name: COLUMN transaction_template_taggings.transaction_tag_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_template_taggings.transaction_tag_id IS 'Applied transaction tag';


--
-- Name: transaction_template_taggings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transaction_template_taggings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_template_taggings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transaction_template_taggings_id_seq OWNED BY public.transaction_template_taggings.id;


--
-- Name: transaction_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction_templates (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    account_id bigint NOT NULL,
    destination_account_id bigint,
    transaction_category_id bigint,
    template_kind integer NOT NULL,
    transaction_kind integer NOT NULL,
    name text NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    source_amount_cents integer DEFAULT 0 NOT NULL,
    destination_amount_cents integer DEFAULT 0 NOT NULL,
    hide_amount boolean DEFAULT false NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    schedule_frequency integer DEFAULT 0 NOT NULL,
    schedule_rule text DEFAULT ''::text NOT NULL,
    schedule_start_on date,
    schedule_end_on date,
    scheduled_at_minutes integer DEFAULT 0 NOT NULL,
    timezone_utc_offset_minutes integer DEFAULT 0 NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    discarded_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    last_generated_on date,
    CONSTRAINT transaction_templates_destination_account_differs CHECK (((destination_account_id IS NULL) OR (destination_account_id <> account_id))),
    CONSTRAINT transaction_templates_schedule_frequency_valid CHECK ((schedule_frequency = ANY (ARRAY[0, 1, 2, 3, 4]))),
    CONSTRAINT transaction_templates_scheduled_at_minutes_range CHECK (((scheduled_at_minutes >= 0) AND (scheduled_at_minutes <= 1439))),
    CONSTRAINT transaction_templates_template_kind_valid CHECK ((template_kind = ANY (ARRAY[1, 2]))),
    CONSTRAINT transaction_templates_timezone_offset_range CHECK (((timezone_utc_offset_minutes >= '-720'::integer) AND (timezone_utc_offset_minutes <= 840))),
    CONSTRAINT transaction_templates_transaction_kind_valid CHECK ((transaction_kind = ANY (ARRAY[1, 2, 3, 4])))
);


--
-- Name: TABLE transaction_templates; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.transaction_templates IS 'User-owned transaction templates and schedules';


--
-- Name: COLUMN transaction_templates.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.user_id IS 'Owner of this template';


--
-- Name: COLUMN transaction_templates.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.account_id IS 'Source account for generated transactions';


--
-- Name: COLUMN transaction_templates.destination_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.destination_account_id IS 'Destination account for transfer templates';


--
-- Name: COLUMN transaction_templates.transaction_category_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.transaction_category_id IS 'Category for generated transactions';


--
-- Name: COLUMN transaction_templates.template_kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.template_kind IS 'Template kind code: normal or scheduled';


--
-- Name: COLUMN transaction_templates.transaction_kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.transaction_kind IS 'Generated transaction kind code';


--
-- Name: COLUMN transaction_templates.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.name IS 'Human-readable template name';


--
-- Name: COLUMN transaction_templates.display_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.display_order IS 'User-controlled display order';


--
-- Name: COLUMN transaction_templates.source_amount_cents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.source_amount_cents IS 'Source amount in cents';


--
-- Name: COLUMN transaction_templates.destination_amount_cents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.destination_amount_cents IS 'Destination amount in cents for transfers';


--
-- Name: COLUMN transaction_templates.hide_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.hide_amount IS 'Whether generated transaction amount is hidden';


--
-- Name: COLUMN transaction_templates.comment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.comment IS 'Optional generated transaction note';


--
-- Name: COLUMN transaction_templates.schedule_frequency; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.schedule_frequency IS 'Schedule frequency code';


--
-- Name: COLUMN transaction_templates.schedule_rule; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.schedule_rule IS 'Frequency-specific schedule rule';


--
-- Name: COLUMN transaction_templates.schedule_start_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.schedule_start_on IS 'First date this schedule may run';


--
-- Name: COLUMN transaction_templates.schedule_end_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.schedule_end_on IS 'Last date this schedule may run';


--
-- Name: COLUMN transaction_templates.scheduled_at_minutes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.scheduled_at_minutes IS 'Minute of local day to run scheduled template';


--
-- Name: COLUMN transaction_templates.timezone_utc_offset_minutes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.timezone_utc_offset_minutes IS 'Template timezone UTC offset in minutes';


--
-- Name: COLUMN transaction_templates.hidden; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.hidden IS 'Whether the template is hidden in normal lists';


--
-- Name: COLUMN transaction_templates.discarded_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.discarded_at IS 'Soft deletion timestamp';


--
-- Name: COLUMN transaction_templates.last_generated_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transaction_templates.last_generated_on IS 'Template-local date that last generated a transaction';


--
-- Name: transaction_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transaction_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transaction_templates_id_seq OWNED BY public.transaction_templates.id;


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
    transaction_category_id bigint,
    CONSTRAINT transactions_balance_adjustment_has_no_category CHECK (((transaction_kind <> 1) OR (transaction_category_id IS NULL))),
    CONSTRAINT transactions_destination_amount_range CHECK (((destination_amount_cents >= '-99999999999'::bigint) AND (destination_amount_cents <= '99999999999'::bigint))),
    CONSTRAINT transactions_destination_differs_from_source CHECK (((destination_account_id IS NULL) OR (destination_account_id <> account_id))),
    CONSTRAINT transactions_kind_valid CHECK ((transaction_kind = ANY (ARRAY[1, 2, 3, 4]))),
    CONSTRAINT transactions_non_transfer_has_no_destination CHECK (((transaction_kind = 4) OR (destination_account_id IS NULL))),
    CONSTRAINT transactions_normal_category_required CHECK (((transaction_kind = 1) OR (transaction_category_id IS NOT NULL))),
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
-- Name: COLUMN transactions.transaction_category_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.transactions.transaction_category_id IS 'Category assigned to normal transactions';


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
-- Name: two_factor_authentications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.two_factor_authentications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    otp_secret text NOT NULL,
    enabled_at timestamp(6) with time zone NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: TABLE two_factor_authentications; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.two_factor_authentications IS 'User-owned TOTP two-factor settings';


--
-- Name: COLUMN two_factor_authentications.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.two_factor_authentications.user_id IS 'Owner of this two-factor setting';


--
-- Name: COLUMN two_factor_authentications.otp_secret; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.two_factor_authentications.otp_secret IS 'Base32 TOTP secret for authenticator apps';


--
-- Name: COLUMN two_factor_authentications.enabled_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.two_factor_authentications.enabled_at IS 'Time two-factor authentication was enabled';


--
-- Name: two_factor_authentications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.two_factor_authentications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: two_factor_authentications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.two_factor_authentications_id_seq OWNED BY public.two_factor_authentications.id;


--
-- Name: two_factor_recovery_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.two_factor_recovery_codes (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    code_digest text NOT NULL,
    used_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: TABLE two_factor_recovery_codes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.two_factor_recovery_codes IS 'User-owned one-time 2FA recovery code digests';


--
-- Name: COLUMN two_factor_recovery_codes.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.two_factor_recovery_codes.user_id IS 'Owner of this recovery code';


--
-- Name: COLUMN two_factor_recovery_codes.code_digest; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.two_factor_recovery_codes.code_digest IS 'BCrypt digest of the raw recovery code';


--
-- Name: COLUMN two_factor_recovery_codes.used_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.two_factor_recovery_codes.used_at IS 'Time this recovery code was consumed';


--
-- Name: two_factor_recovery_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.two_factor_recovery_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: two_factor_recovery_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.two_factor_recovery_codes_id_seq OWNED BY public.two_factor_recovery_codes.id;


--
-- Name: user_custom_exchange_rates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_custom_exchange_rates (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    currency_code text NOT NULL,
    rate_scaled bigint NOT NULL,
    discarded_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT user_custom_exchange_rates_currency_code_length CHECK ((char_length(currency_code) = 3)),
    CONSTRAINT user_custom_exchange_rates_rate_scaled_positive CHECK ((rate_scaled > 0))
);


--
-- Name: TABLE user_custom_exchange_rates; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_custom_exchange_rates IS 'User-owned custom exchange rates';


--
-- Name: COLUMN user_custom_exchange_rates.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_custom_exchange_rates.user_id IS 'Owner of this custom exchange rate';


--
-- Name: COLUMN user_custom_exchange_rates.currency_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_custom_exchange_rates.currency_code IS 'ISO 4217 currency code for this override';


--
-- Name: COLUMN user_custom_exchange_rates.rate_scaled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_custom_exchange_rates.rate_scaled IS 'Exchange rate scaled by 100,000,000 relative to the user''s default currency';


--
-- Name: COLUMN user_custom_exchange_rates.discarded_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_custom_exchange_rates.discarded_at IS 'Soft deletion timestamp';


--
-- Name: user_custom_exchange_rates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_custom_exchange_rates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_custom_exchange_rates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_custom_exchange_rates_id_seq OWNED BY public.user_custom_exchange_rates.id;


--
-- Name: user_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_preferences (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    default_currency_code text DEFAULT 'USD'::text NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT user_preferences_default_currency_code_length CHECK ((char_length(default_currency_code) = 3))
);


--
-- Name: TABLE user_preferences; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_preferences IS 'User-owned display and ledger defaults';


--
-- Name: COLUMN user_preferences.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_preferences.user_id IS 'Owner of these preferences';


--
-- Name: COLUMN user_preferences.default_currency_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_preferences.default_currency_code IS 'ISO 4217 default currency code for new ledger records';


--
-- Name: user_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_preferences_id_seq OWNED BY public.user_preferences.id;


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
-- Name: api_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens ALTER COLUMN id SET DEFAULT nextval('public.api_tokens_id_seq'::regclass);


--
-- Name: application_locks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_locks ALTER COLUMN id SET DEFAULT nextval('public.application_locks_id_seq'::regclass);


--
-- Name: import_batches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_batches ALTER COLUMN id SET DEFAULT nextval('public.import_batches_id_seq'::regclass);


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
-- Name: transaction_template_taggings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_template_taggings ALTER COLUMN id SET DEFAULT nextval('public.transaction_template_taggings_id_seq'::regclass);


--
-- Name: transaction_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_templates ALTER COLUMN id SET DEFAULT nextval('public.transaction_templates_id_seq'::regclass);


--
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.transactions_id_seq'::regclass);


--
-- Name: two_factor_authentications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.two_factor_authentications ALTER COLUMN id SET DEFAULT nextval('public.two_factor_authentications_id_seq'::regclass);


--
-- Name: two_factor_recovery_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.two_factor_recovery_codes ALTER COLUMN id SET DEFAULT nextval('public.two_factor_recovery_codes_id_seq'::regclass);


--
-- Name: user_custom_exchange_rates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_custom_exchange_rates ALTER COLUMN id SET DEFAULT nextval('public.user_custom_exchange_rates_id_seq'::regclass);


--
-- Name: user_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences ALTER COLUMN id SET DEFAULT nextval('public.user_preferences_id_seq'::regclass);


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
-- Name: api_tokens api_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_pkey PRIMARY KEY (id);


--
-- Name: application_locks application_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_locks
    ADD CONSTRAINT application_locks_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: import_batches import_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_batches
    ADD CONSTRAINT import_batches_pkey PRIMARY KEY (id);


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
-- Name: transaction_template_taggings transaction_template_taggings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_template_taggings
    ADD CONSTRAINT transaction_template_taggings_pkey PRIMARY KEY (id);


--
-- Name: transaction_templates transaction_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_templates
    ADD CONSTRAINT transaction_templates_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: two_factor_authentications two_factor_authentications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.two_factor_authentications
    ADD CONSTRAINT two_factor_authentications_pkey PRIMARY KEY (id);


--
-- Name: two_factor_recovery_codes two_factor_recovery_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.two_factor_recovery_codes
    ADD CONSTRAINT two_factor_recovery_codes_pkey PRIMARY KEY (id);


--
-- Name: user_custom_exchange_rates user_custom_exchange_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_custom_exchange_rates
    ADD CONSTRAINT user_custom_exchange_rates_pkey PRIMARY KEY (id);


--
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (id);


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
-- Name: index_api_tokens_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_tokens_on_discarded_at ON public.api_tokens USING btree (discarded_at);


--
-- Name: index_api_tokens_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_tokens_on_expires_at ON public.api_tokens USING btree (expires_at);


--
-- Name: index_api_tokens_on_owner_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_tokens_on_owner_discarded_at ON public.api_tokens USING btree (user_id, discarded_at);


--
-- Name: index_api_tokens_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_tokens_on_user_id ON public.api_tokens USING btree (user_id);


--
-- Name: index_application_locks_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_application_locks_on_user_id ON public.application_locks USING btree (user_id);


--
-- Name: index_import_batches_on_owner_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_import_batches_on_owner_created_at ON public.import_batches USING btree (user_id, created_at);


--
-- Name: index_import_batches_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_import_batches_on_user_id ON public.import_batches USING btree (user_id);


--
-- Name: index_template_taggings_on_template_and_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_template_taggings_on_template_and_tag ON public.transaction_template_taggings USING btree (transaction_template_id, transaction_tag_id);


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
-- Name: index_transaction_template_taggings_on_transaction_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_template_taggings_on_transaction_tag_id ON public.transaction_template_taggings USING btree (transaction_tag_id);


--
-- Name: index_transaction_template_taggings_on_transaction_template_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_template_taggings_on_transaction_template_id ON public.transaction_template_taggings USING btree (transaction_template_id);


--
-- Name: index_transaction_template_taggings_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_template_taggings_on_user_id ON public.transaction_template_taggings USING btree (user_id);


--
-- Name: index_transaction_templates_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_templates_on_account_id ON public.transaction_templates USING btree (account_id);


--
-- Name: index_transaction_templates_on_destination_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_templates_on_destination_account_id ON public.transaction_templates USING btree (destination_account_id);


--
-- Name: index_transaction_templates_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_templates_on_discarded_at ON public.transaction_templates USING btree (discarded_at);


--
-- Name: index_transaction_templates_on_owner_kind_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_templates_on_owner_kind_order ON public.transaction_templates USING btree (user_id, template_kind, display_order);


--
-- Name: index_transaction_templates_on_schedule_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_templates_on_schedule_lookup ON public.transaction_templates USING btree (discarded_at, template_kind, schedule_frequency, schedule_start_on, schedule_end_on);


--
-- Name: index_transaction_templates_on_transaction_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_templates_on_transaction_category_id ON public.transaction_templates USING btree (transaction_category_id);


--
-- Name: index_transaction_templates_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transaction_templates_on_user_id ON public.transaction_templates USING btree (user_id);


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
-- Name: index_transactions_on_owner_category_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_owner_category_time ON public.transactions USING btree (user_id, transaction_category_id, transacted_at);


--
-- Name: index_transactions_on_owner_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_owner_time ON public.transactions USING btree (user_id, transacted_at);


--
-- Name: index_transactions_on_transaction_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_transaction_category_id ON public.transactions USING btree (transaction_category_id);


--
-- Name: index_transactions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_transactions_on_user_id ON public.transactions USING btree (user_id);


--
-- Name: index_two_factor_authentications_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_two_factor_authentications_on_user_id ON public.two_factor_authentications USING btree (user_id);


--
-- Name: index_two_factor_recovery_codes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_two_factor_recovery_codes_on_user_id ON public.two_factor_recovery_codes USING btree (user_id);


--
-- Name: index_two_factor_recovery_codes_on_user_id_and_used_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_two_factor_recovery_codes_on_user_id_and_used_at ON public.two_factor_recovery_codes USING btree (user_id, used_at);


--
-- Name: index_user_custom_exchange_rates_on_active_owner_currency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_custom_exchange_rates_on_active_owner_currency ON public.user_custom_exchange_rates USING btree (user_id, currency_code) WHERE (discarded_at IS NULL);


--
-- Name: index_user_custom_exchange_rates_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_custom_exchange_rates_on_discarded_at ON public.user_custom_exchange_rates USING btree (discarded_at);


--
-- Name: index_user_custom_exchange_rates_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_custom_exchange_rates_on_user_id ON public.user_custom_exchange_rates USING btree (user_id);


--
-- Name: index_user_preferences_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_preferences_on_user_id ON public.user_preferences USING btree (user_id);


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
-- Name: two_factor_authentications fk_rails_110abb6ee6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.two_factor_authentications
    ADD CONSTRAINT fk_rails_110abb6ee6 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: import_batches fk_rails_12f3440250; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_batches
    ADD CONSTRAINT fk_rails_12f3440250 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transaction_template_taggings fk_rails_1666aa3e82; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_template_taggings
    ADD CONSTRAINT fk_rails_1666aa3e82 FOREIGN KEY (transaction_tag_id) REFERENCES public.transaction_tags(id);


--
-- Name: two_factor_recovery_codes fk_rails_1b41033e31; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.two_factor_recovery_codes
    ADD CONSTRAINT fk_rails_1b41033e31 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transaction_template_taggings fk_rails_2fe1eca187; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_template_taggings
    ADD CONSTRAINT fk_rails_2fe1eca187 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: application_locks fk_rails_3e7754d4df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_locks
    ADD CONSTRAINT fk_rails_3e7754d4df FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transaction_categories fk_rails_4b9fac99aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_categories
    ADD CONSTRAINT fk_rails_4b9fac99aa FOREIGN KEY (parent_category_id) REFERENCES public.transaction_categories(id);


--
-- Name: transaction_templates fk_rails_52511449d0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_templates
    ADD CONSTRAINT fk_rails_52511449d0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transaction_template_taggings fk_rails_693dd307f2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_template_taggings
    ADD CONSTRAINT fk_rails_693dd307f2 FOREIGN KEY (transaction_template_id) REFERENCES public.transaction_templates(id);


--
-- Name: user_custom_exchange_rates fk_rails_6b9003de2b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_custom_exchange_rates
    ADD CONSTRAINT fk_rails_6b9003de2b FOREIGN KEY (user_id) REFERENCES public.users(id);


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
-- Name: transaction_templates fk_rails_97ebc054e3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_templates
    ADD CONSTRAINT fk_rails_97ebc054e3 FOREIGN KEY (transaction_category_id) REFERENCES public.transaction_categories(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: user_preferences fk_rails_a69bfcfd81; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT fk_rails_a69bfcfd81 FOREIGN KEY (user_id) REFERENCES public.users(id);


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
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: transactions fk_rails_cd0480b0ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_cd0480b0ce FOREIGN KEY (transaction_category_id) REFERENCES public.transaction_categories(id);


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
-- Name: api_tokens fk_rails_f16b5e0447; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT fk_rails_f16b5e0447 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transaction_taggings fk_rails_f277d342d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_taggings
    ADD CONSTRAINT fk_rails_f277d342d3 FOREIGN KEY (transaction_tag_id) REFERENCES public.transaction_tags(id);


--
-- Name: transaction_templates fk_rails_f592def69f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_templates
    ADD CONSTRAINT fk_rails_f592def69f FOREIGN KEY (destination_account_id) REFERENCES public.accounts(id);


--
-- Name: transactions fk_rails_f7070c25b3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_f7070c25b3 FOREIGN KEY (destination_account_id) REFERENCES public.accounts(id);


--
-- Name: transaction_templates fk_rails_fd7985cecd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_templates
    ADD CONSTRAINT fk_rails_fd7985cecd FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260503200001'),
('20260503200000'),
('20260503190000'),
('20260503180000'),
('20260503170000'),
('20260503160000'),
('20260503150000'),
('20260503140000'),
('20260503130000'),
('20260503120000'),
('20260503110000'),
('20260503100000'),
('20260503090000'),
('20260411171621');

