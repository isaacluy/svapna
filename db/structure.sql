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
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: svapna_regconfig(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.svapna_regconfig(lang text) RETURNS regconfig
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
  SELECT CASE lang
    WHEN 'es' THEN 'public.svapna_es'::regconfig
    WHEN 'en' THEN 'public.svapna_en'::regconfig
    ELSE 'pg_catalog.simple'::regconfig
  END
$$;


--
-- Name: svapna_en; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.svapna_en (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR asciiword WITH english_stem;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR word WITH public.unaccent, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR hword_part WITH public.unaccent, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR hword_asciipart WITH english_stem;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR asciihword WITH english_stem;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR hword WITH public.unaccent, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_en
    ADD MAPPING FOR uint WITH simple;


--
-- Name: svapna_es; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.svapna_es (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR asciiword WITH spanish_stem;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR word WITH public.unaccent, spanish_stem;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR hword_part WITH public.unaccent, spanish_stem;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR hword_asciipart WITH spanish_stem;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR asciihword WITH spanish_stem;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR hword WITH public.unaccent, spanish_stem;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.svapna_es
    ADD MAPPING FOR uint WITH simple;


SET default_tablespace = '';

SET default_table_access_method = heap;

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
-- Name: entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entries (
    id bigint NOT NULL,
    body text NOT NULL,
    written_on date NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    language character varying DEFAULT 'es'::character varying NOT NULL,
    status character varying DEFAULT 'published'::character varying NOT NULL,
    source character varying,
    body_digest character varying NOT NULL,
    import_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    search_vector tsvector GENERATED ALWAYS AS ((setweight(to_tsvector(public.svapna_regconfig((language)::text), COALESCE(body, ''::text)), 'A'::"char") || setweight(to_tsvector(public.svapna_regconfig((language)::text), (COALESCE(source, ''::character varying))::text), 'C'::"char"))) STORED,
    word_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple'::regconfig, COALESCE(body, ''::text))) STORED
);


--
-- Name: entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entries_id_seq OWNED BY public.entries.id;


--
-- Name: imports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imports (
    id bigint NOT NULL,
    source character varying,
    filename character varying,
    entries_count integer DEFAULT 0 NOT NULL,
    duplicate_count integer DEFAULT 0 NOT NULL,
    skipped_count integer DEFAULT 0 NOT NULL,
    parse_errors jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: imports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.imports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: imports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.imports_id_seq OWNED BY public.imports.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
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
-- Name: entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries ALTER COLUMN id SET DEFAULT nextval('public.entries_id_seq'::regclass);


--
-- Name: imports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imports ALTER COLUMN id SET DEFAULT nextval('public.imports_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: entries entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT entries_pkey PRIMARY KEY (id);


--
-- Name: imports imports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imports
    ADD CONSTRAINT imports_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_entries_on_import_dedupe; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entries_on_import_dedupe ON public.entries USING btree (written_on, body_digest) WHERE (import_id IS NOT NULL);


--
-- Name: index_entries_on_import_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_import_id ON public.entries USING btree (import_id);


--
-- Name: index_entries_on_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_search_vector ON public.entries USING gin (search_vector);


--
-- Name: index_entries_on_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_source ON public.entries USING btree (source);


--
-- Name: index_entries_on_status_and_written_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_status_and_written_on ON public.entries USING btree (status, written_on DESC);


--
-- Name: index_entries_on_word_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_word_vector ON public.entries USING gin (word_vector);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: entries fk_rails_f8a7316f9a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_f8a7316f9a FOREIGN KEY (import_id) REFERENCES public.imports(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260920182421'),
('20260920170757'),
('20260920170755'),
('20260920153423'),
('20260920153422');

