--
-- PostgreSQL database dump
--

-- Dumped from database version 14.13 (Ubuntu 14.13-1.pgdg22.04+1)
-- Dumped by pg_dump version 14.13 (Ubuntu 14.13-0ubuntu0.22.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
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
-- Name: EducationLevel; Type: TABLE; Schema: public; Owner: iconicactionstesting
--

CREATE TABLE public."EducationLevel" (
    id integer NOT NULL,
    code text NOT NULL,
    name text NOT NULL
);


ALTER TABLE public."EducationLevel" OWNER TO iconicactionstesting;

--
-- Name: EducationLevel_id_seq; Type: SEQUENCE; Schema: public; Owner: iconicactionstesting
--

CREATE SEQUENCE public."EducationLevel_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."EducationLevel_id_seq" OWNER TO iconicactionstesting;

--
-- Name: EducationLevel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: iconicactionstesting
--

ALTER SEQUENCE public."EducationLevel_id_seq" OWNED BY public."EducationLevel".id;


--
-- Name: Post; Type: TABLE; Schema: public; Owner: iconicactionstesting
--

CREATE TABLE public."Post" (
    id integer NOT NULL,
    title text NOT NULL,
    content text,
    published boolean DEFAULT false NOT NULL,
    "authorId" integer NOT NULL
);


ALTER TABLE public."Post" OWNER TO iconicactionstesting;

--
-- Name: Post_id_seq; Type: SEQUENCE; Schema: public; Owner: iconicactionstesting
--

CREATE SEQUENCE public."Post_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."Post_id_seq" OWNER TO iconicactionstesting;

--
-- Name: Post_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: iconicactionstesting
--

ALTER SEQUENCE public."Post_id_seq" OWNED BY public."Post".id;


--
-- Name: User; Type: TABLE; Schema: public; Owner: iconicactionstesting
--

CREATE TABLE public."User" (
    id integer NOT NULL,
    email text NOT NULL,
    name text
);


ALTER TABLE public."User" OWNER TO iconicactionstesting;

--
-- Name: User_id_seq; Type: SEQUENCE; Schema: public; Owner: iconicactionstesting
--

CREATE SEQUENCE public."User_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."User_id_seq" OWNER TO iconicactionstesting;

--
-- Name: User_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: iconicactionstesting
--

ALTER SEQUENCE public."User_id_seq" OWNED BY public."User".id;


--
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: iconicactionstesting
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public._prisma_migrations OWNER TO iconicactionstesting;

--
-- Name: EducationLevel id; Type: DEFAULT; Schema: public; Owner: iconicactionstesting
--

ALTER TABLE ONLY public."EducationLevel" ALTER COLUMN id SET DEFAULT nextval('public."EducationLevel_id_seq"'::regclass);


--
-- Name: Post id; Type: DEFAULT; Schema: public; Owner: iconicactionstesting
--

ALTER TABLE ONLY public."Post" ALTER COLUMN id SET DEFAULT nextval('public."Post_id_seq"'::regclass);


--
-- Name: User id; Type: DEFAULT; Schema: public; Owner: iconicactionstesting
--

ALTER TABLE ONLY public."User" ALTER COLUMN id SET DEFAULT nextval('public."User_id_seq"'::regclass);


--
-- Data for Name: EducationLevel; Type: TABLE DATA; Schema: public; Owner: iconicactionstesting
--

COPY public."EducationLevel" (id, code, name) FROM stdin;
1	secondary	Среднее
2	special_secondary	Среднее специальное
3	unfinished_higher	Неоконченное высшее
4	higher	Высшее
5	bachelor	Бакалавр
6	master	Магистр
7	candidate	Кандидат наук
8	doctor	Доктор наук
\.


--
-- Data for Name: Post; Type: TABLE DATA; Schema: public; Owner: iconicactionstesting
--

COPY public."Post" (id, title, content, published, "authorId") FROM stdin;
\.


--
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: iconicactionstesting
--

COPY public."User" (id, email, name) FROM stdin;
1	alice@prisma.io	Alice
\.


--
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: iconicactionstesting
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
1be23e7e-3a99-4bf8-a494-a034f23b1169	ad6f19d4e4562c0e2b9f616ba2f2470a28d3bfc2bdca20b611be938598de7e63	2024-10-03 13:30:40.519175+03	20231003080317_init	\N	\N	2024-10-03 13:30:40.490034+03	1
c92ffaeb-fa94-4f4a-9263-df73f3e73476	e240624b6625098b29c8a36e4fd6a45e7d31789b931071f7b72f2df36bb42598	2024-10-03 13:30:40.538505+03	20231003085511_education_level	\N	\N	2024-10-03 13:30:40.521413+03	1
\.


--
-- Name: EducationLevel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: iconicactionstesting
--

SELECT pg_catalog.setval('public."EducationLevel_id_seq"', 8, true);


--
-- Name: Post_id_seq; Type: SEQUENCE SET; Schema: public; Owner: iconicactionstesting
--

SELECT pg_catalog.setval('public."Post_id_seq"', 1, false);


--
-- Name: User_id_seq; Type: SEQUENCE SET; Schema: public; Owner: iconicactionstesting
--

SELECT pg_catalog.setval('public."User_id_seq"', 2, true);


--
-- Name: EducationLevel EducationLevel_pkey; Type: CONSTRAINT; Schema: public; Owner: iconicactionstesting
--

ALTER TABLE ONLY public."EducationLevel"
    ADD CONSTRAINT "EducationLevel_pkey" PRIMARY KEY (id);


--
-- Name: Post Post_pkey; Type: CONSTRAINT; Schema: public; Owner: iconicactionstesting
--

ALTER TABLE ONLY public."Post"
    ADD CONSTRAINT "Post_pkey" PRIMARY KEY (id);


--
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: iconicactionstesting
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (id);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: iconicactionstesting
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: EducationLevel_code_key; Type: INDEX; Schema: public; Owner: iconicactionstesting
--

CREATE UNIQUE INDEX "EducationLevel_code_key" ON public."EducationLevel" USING btree (code);


--
-- Name: User_email_key; Type: INDEX; Schema: public; Owner: iconicactionstesting
--

CREATE UNIQUE INDEX "User_email_key" ON public."User" USING btree (email);


--
-- Name: Post Post_authorId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: iconicactionstesting
--

ALTER TABLE ONLY public."Post"
    ADD CONSTRAINT "Post_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

