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
-- Name: events; Type: TABLE; Schema: public; Owner: docker
--

CREATE TABLE public.events (
    event_id bigint NOT NULL,
    aggregate_type character varying(50),
    aggregate_id character varying(100),
    event_type character varying(50),
    event_data jsonb,
    user_id character varying(100),
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE ("timestamp");


ALTER TABLE public.events OWNER TO docker;

--
-- Name: events_event_id_seq; Type: SEQUENCE; Schema: public; Owner: docker
--

CREATE SEQUENCE public.events_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.events_event_id_seq OWNER TO docker;

--
-- Name: events_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: docker
--

ALTER SEQUENCE public.events_event_id_seq OWNED BY public.events.event_id;


--
-- Name: events_2025_10; Type: TABLE; Schema: public; Owner: docker
--

CREATE TABLE public.events_2025_10 (
    event_id bigint DEFAULT nextval('public.events_event_id_seq'::regclass) NOT NULL,
    aggregate_type character varying(50),
    aggregate_id character varying(100),
    event_type character varying(50),
    event_data jsonb,
    user_id character varying(100),
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE ONLY public.events ATTACH PARTITION public.events_2025_10 FOR VALUES FROM ('2025-10-01 00:00:00+00') TO ('2025-11-01 00:00:00+00');


ALTER TABLE public.events_2025_10 OWNER TO docker;

--
-- Name: events_2025_11; Type: TABLE; Schema: public; Owner: docker
--

CREATE TABLE public.events_2025_11 (
    event_id bigint DEFAULT nextval('public.events_event_id_seq'::regclass) NOT NULL,
    aggregate_type character varying(50),
    aggregate_id character varying(100),
    event_type character varying(50),
    event_data jsonb,
    user_id character varying(100),
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE ONLY public.events ATTACH PARTITION public.events_2025_11 FOR VALUES FROM ('2025-11-01 00:00:00+00') TO ('2025-12-01 00:00:00+00');


ALTER TABLE public.events_2025_11 OWNER TO docker;

--
-- Name: events_2025_12; Type: TABLE; Schema: public; Owner: docker
--

CREATE TABLE public.events_2025_12 (
    event_id bigint DEFAULT nextval('public.events_event_id_seq'::regclass) NOT NULL,
    aggregate_type character varying(50),
    aggregate_id character varying(100),
    event_type character varying(50),
    event_data jsonb,
    user_id character varying(100),
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE ONLY public.events ATTACH PARTITION public.events_2025_12 FOR VALUES FROM ('2025-12-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


ALTER TABLE public.events_2025_12 OWNER TO docker;

--
-- Name: events event_id; Type: DEFAULT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.events ALTER COLUMN event_id SET DEFAULT nextval('public.events_event_id_seq'::regclass);


--
-- Data for Name: events_2025_10; Type: TABLE DATA; Schema: public; Owner: docker
--

COPY public.events_2025_10 (event_id, aggregate_type, aggregate_id, event_type, event_data, user_id, "timestamp") FROM stdin;
\.


--
-- Data for Name: events_2025_11; Type: TABLE DATA; Schema: public; Owner: docker
--

COPY public.events_2025_11 (event_id, aggregate_type, aggregate_id, event_type, event_data, user_id, "timestamp") FROM stdin;
\.


--
-- Data for Name: events_2025_12; Type: TABLE DATA; Schema: public; Owner: docker
--

COPY public.events_2025_12 (event_id, aggregate_type, aggregate_id, event_type, event_data, user_id, "timestamp") FROM stdin;
\.


--
-- Name: events_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: docker
--

SELECT pg_catalog.setval('public.events_event_id_seq', 1, false);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (event_id, "timestamp");


--
-- Name: events_2025_10 events_2025_10_pkey; Type: CONSTRAINT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.events_2025_10
    ADD CONSTRAINT events_2025_10_pkey PRIMARY KEY (event_id, "timestamp");


--
-- Name: events_2025_11 events_2025_11_pkey; Type: CONSTRAINT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.events_2025_11
    ADD CONSTRAINT events_2025_11_pkey PRIMARY KEY (event_id, "timestamp");


--
-- Name: events_2025_12 events_2025_12_pkey; Type: CONSTRAINT; Schema: public; Owner: docker
--

ALTER TABLE ONLY public.events_2025_12
    ADD CONSTRAINT events_2025_12_pkey PRIMARY KEY (event_id, "timestamp");


--
-- Name: idx_events_aggregate; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX idx_events_aggregate ON ONLY public.events USING btree (aggregate_type, aggregate_id);


--
-- Name: events_2025_10_aggregate_type_aggregate_id_idx; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX events_2025_10_aggregate_type_aggregate_id_idx ON public.events_2025_10 USING btree (aggregate_type, aggregate_id);


--
-- Name: idx_events_timestamp; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX idx_events_timestamp ON ONLY public.events USING btree ("timestamp");


--
-- Name: events_2025_10_timestamp_idx; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX events_2025_10_timestamp_idx ON public.events_2025_10 USING btree ("timestamp");


--
-- Name: events_2025_11_aggregate_type_aggregate_id_idx; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX events_2025_11_aggregate_type_aggregate_id_idx ON public.events_2025_11 USING btree (aggregate_type, aggregate_id);


--
-- Name: events_2025_11_timestamp_idx; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX events_2025_11_timestamp_idx ON public.events_2025_11 USING btree ("timestamp");


--
-- Name: events_2025_12_aggregate_type_aggregate_id_idx; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX events_2025_12_aggregate_type_aggregate_id_idx ON public.events_2025_12 USING btree (aggregate_type, aggregate_id);


--
-- Name: events_2025_12_timestamp_idx; Type: INDEX; Schema: public; Owner: docker
--

CREATE INDEX events_2025_12_timestamp_idx ON public.events_2025_12 USING btree ("timestamp");


--
-- Name: events_2025_10_aggregate_type_aggregate_id_idx; Type: INDEX ATTACH; Schema: public; Owner: docker
--

ALTER INDEX public.idx_events_aggregate ATTACH PARTITION public.events_2025_10_aggregate_type_aggregate_id_idx;


--
-- Name: events_2025_10_pkey; Type: INDEX ATTACH; Schema: public; Owner: docker
--

ALTER INDEX public.events_pkey ATTACH PARTITION public.events_2025_10_pkey;


--
-- Name: events_2025_10_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: docker
--

ALTER INDEX public.idx_events_timestamp ATTACH PARTITION public.events_2025_10_timestamp_idx;


--
-- Name: events_2025_11_aggregate_type_aggregate_id_idx; Type: INDEX ATTACH; Schema: public; Owner: docker
--

ALTER INDEX public.idx_events_aggregate ATTACH PARTITION public.events_2025_11_aggregate_type_aggregate_id_idx;


--
-- Name: events_2025_11_pkey; Type: INDEX ATTACH; Schema: public; Owner: docker
--

ALTER INDEX public.events_pkey ATTACH PARTITION public.events_2025_11_pkey;


--
-- Name: events_2025_11_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: docker
--

ALTER INDEX public.idx_events_timestamp ATTACH PARTITION public.events_2025_11_timestamp_idx;


--
-- Name: events_2025_12_aggregate_type_aggregate_id_idx; Type: INDEX ATTACH; Schema: public; Owner: docker
--

ALTER INDEX public.idx_events_aggregate ATTACH PARTITION public.events_2025_12_aggregate_type_aggregate_id_idx;


--
-- Name: events_2025_12_pkey; Type: INDEX ATTACH; Schema: public; Owner: docker
--

ALTER INDEX public.events_pkey ATTACH PARTITION public.events_2025_12_pkey;


--
-- Name: events_2025_12_timestamp_idx; Type: INDEX ATTACH; Schema: public; Owner: docker
--

ALTER INDEX public.idx_events_timestamp ATTACH PARTITION public.events_2025_12_timestamp_idx;


--
-- PostgreSQL database dump complete
--

