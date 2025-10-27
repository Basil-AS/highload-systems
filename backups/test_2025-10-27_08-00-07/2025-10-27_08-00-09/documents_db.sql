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
-- Name: documents; Type: TABLE; Schema: public; Owner: docker
--

CREATE TABLE public.documents (
    id integer NOT NULL,
    title character varying(500) NOT NULL,
    content text NOT NULL,
    author character varying(255),
    metadata jsonb,
    indexed boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.documents OWNER TO docker;

--
-- Name: documents_id_seq; Type: SEQUENCE; Schema: public; Owner: docker
--

CREATE SEQUENCE public.documents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.documents_id_seq OWNER TO docker;

--
-- Name: documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: docker
--

ALTER SEQUENCE public.documents_id_seq OWNED BY public.documents.id;


--
-- Name: documents id; Type: DEFAULT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.documents ALTER COLUMN id SET DEFAULT nextval('public.documents_id_seq'::regclass);


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: docker
--

COPY public.documents (id, title, content, author, metadata, indexed, created_at, updated_at) FROM stdin;
1	Test Doc	Test content for backup	Test Author	\N	f	2025-10-27 04:58:42.849209	2025-10-27 04:58:42.849209
2	Test Doc	Test content for backup	Test Author	\N	f	2025-10-27 05:00:08.663951	2025-10-27 05:00:08.663951
\.


--
-- Name: documents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: docker
--

SELECT pg_catalog.setval('public.documents_id_seq', 2, true);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: idx_documents_indexed; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX idx_documents_indexed ON public.documents USING btree (indexed);


--
-- Name: idx_documents_title; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX idx_documents_title ON public.documents USING gin (to_tsvector('english'::regconfig, (title)::text));


--
-- PostgreSQL database dump complete
--

