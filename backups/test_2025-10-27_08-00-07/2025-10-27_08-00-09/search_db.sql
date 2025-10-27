--
-- PostgreSQL database dump
--

-- Dumped from database version 11.12 (Debian 11.12-0+deb10u1)
-- Dumped by pg_dump version 11.12 (Debian 11.12-0+deb10u1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'SQL_ASCII';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: postings; Type: TABLE; Schema: public; Owner: docker
--

CREATE TABLE public.postings (
    id integer NOT NULL,
    term_id integer,
    doc_id integer NOT NULL,
    positions integer[],
    tf_idf double precision DEFAULT 0.0,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.postings OWNER TO docker;

--
-- Name: postings_id_seq; Type: SEQUENCE; Schema: public; Owner: docker
--

CREATE SEQUENCE public.postings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.postings_id_seq OWNER TO docker;

--
-- Name: postings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: docker
--

ALTER SEQUENCE public.postings_id_seq OWNED BY public.postings.id;


--
-- Name: search_documents; Type: TABLE; Schema: public; Owner: docker
--

CREATE TABLE public.search_documents (
    id integer NOT NULL,
    title character varying(500),
    snippet text,
    indexed_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.search_documents OWNER TO docker;

--
-- Name: terms; Type: TABLE; Schema: public; Owner: docker
--

CREATE TABLE public.terms (
    id integer NOT NULL,
    term character varying(255) NOT NULL
);


ALTER TABLE public.terms OWNER TO docker;

--
-- Name: terms_id_seq; Type: SEQUENCE; Schema: public; Owner: docker
--

CREATE SEQUENCE public.terms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.terms_id_seq OWNER TO docker;

--
-- Name: terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: docker
--

ALTER SEQUENCE public.terms_id_seq OWNED BY public.terms.id;


--
-- Name: postings id; Type: DEFAULT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.postings ALTER COLUMN id SET DEFAULT nextval('public.postings_id_seq'::regclass);


--
-- Name: terms id; Type: DEFAULT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.terms ALTER COLUMN id SET DEFAULT nextval('public.terms_id_seq'::regclass);


--
-- Data for Name: postings; Type: TABLE DATA; Schema: public; Owner: docker
--

COPY public.postings (id, term_id, doc_id, positions, tf_idf, created_at) FROM stdin;
\.


--
-- Data for Name: search_documents; Type: TABLE DATA; Schema: public; Owner: docker
--

COPY public.search_documents (id, title, snippet, indexed_at) FROM stdin;
\.


--
-- Data for Name: terms; Type: TABLE DATA; Schema: public; Owner: docker
--

COPY public.terms (id, term) FROM stdin;
\.


--
-- Name: postings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: docker
--

SELECT pg_catalog.setval('public.postings_id_seq', 1, false);


--
-- Name: terms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: docker
--

SELECT pg_catalog.setval('public.terms_id_seq', 1, false);


--
-- Name: postings postings_pkey; Type: CONSTRAINT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_pkey PRIMARY KEY (id);


--
-- Name: search_documents search_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.search_documents
    ADD CONSTRAINT search_documents_pkey PRIMARY KEY (id);


--
-- Name: terms terms_pkey; Type: CONSTRAINT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.terms
    ADD CONSTRAINT terms_pkey PRIMARY KEY (id);


--
-- Name: terms terms_term_key; Type: CONSTRAINT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.terms
    ADD CONSTRAINT terms_term_key UNIQUE (term);


--
-- Name: idx_postings_doc_id; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX idx_postings_doc_id ON public.postings USING btree (doc_id);


--
-- Name: idx_postings_term_id; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX idx_postings_term_id ON public.postings USING btree (term_id);


--
-- Name: idx_terms_term; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX idx_terms_term ON public.terms USING btree (term);


--
-- Name: postings postings_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_term_id_fkey FOREIGN KEY (term_id) REFERENCES public.terms(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

