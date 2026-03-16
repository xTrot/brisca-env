--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5 (Debian 17.5-1.pgdg120+1)
-- Dumped by pg_dump version 17.4

-- Started on 2025-11-15 15:37:46

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
-- TOC entry 6 (class 2615 OID 16389)
-- Name: auth; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA auth;


ALTER SCHEMA auth OWNER TO postgres;

--
-- TOC entry 858 (class 1247 OID 16392)
-- Name: session_return; Type: TYPE; Schema: auth; Owner: postgres
--

CREATE TYPE auth.session_return AS (
	token text,
	refreshby timestamp with time zone,
	username text
);


ALTER TYPE auth.session_return OWNER TO postgres;

--
-- TOC entry 223 (class 1255 OID 16393)
-- Name: create_guest_session(text); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.create_guest_session(p_username text) RETURNS auth.session_return
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_session_row auth.session;
    generated_token TEXT;
    refresh_expiration_time TIMESTAMP WITH TIME ZONE;
BEGIN
    generated_token := gen_random_uuid()::TEXT;

    refresh_expiration_time := NOW() + INTERVAL '15 minutes';

    INSERT INTO auth.session (token, refreshby, owner, username)
    VALUES (generated_token, refresh_expiration_time, NULL, p_username)
    RETURNING * INTO new_session_row;

    RETURN (new_session_row.token, new_session_row.refreshby, new_session_row.username)::auth.session_return;
END;
$$;


ALTER FUNCTION auth.create_guest_session(p_username text) OWNER TO postgres;

--
-- TOC entry 224 (class 1255 OID 16394)
-- Name: get_active_sessions(); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.get_active_sessions() RETURNS SETOF auth.session_return
    LANGUAGE sql
    AS $$
SELECT s.token, s.refreshby, s.username
FROM auth.session s
WHERE refreshby > CURRENT_TIMESTAMP;
$$;


ALTER FUNCTION auth.get_active_sessions() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 24577)
-- Name: gameServer; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth."gameServer" (
    hostname text NOT NULL
);


ALTER TABLE auth."gameServer" OWNER TO postgres;

--
-- TOC entry 227 (class 1255 OID 32772)
-- Name: get_game_servers(); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.get_game_servers() RETURNS SETOF auth."gameServer"
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT hostname
    FROM auth."gameServer";
$$;


ALTER FUNCTION auth.get_game_servers() OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16395)
-- Name: session; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.session (
    token text NOT NULL,
    owner text,
    refreshby timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    username text NOT NULL
);


ALTER TABLE auth.session OWNER TO postgres;

--
-- TOC entry 225 (class 1255 OID 16401)
-- Name: get_session(text); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.get_session(p_token text) RETURNS auth.session
    LANGUAGE plpgsql
    AS $$
DECLARE
    found_session auth.session; -- Declare a variable to hold the session row
BEGIN
    -- Attempt to select the session where the token matches and it's not expired
    SELECT s.token, s.owner, s.refreshby, s.username
    INTO found_session
    FROM auth.session s
    WHERE s.token = p_token
      AND s.refreshby > NOW(); -- Check if the session is still valid (not expired)

    -- Check if a row was found by the SELECT INTO statement
    IF FOUND THEN
        RETURN found_session; -- Return the found (and valid) session row
    ELSE
        RETURN NULL; -- Return NULL if no valid session was found
    END IF;
END;
$$;


ALTER FUNCTION auth.get_session(p_token text) OWNER TO postgres;

--
-- TOC entry 240 (class 1255 OID 16403)
-- Name: refresh_session(text); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.refresh_session(p_token text) RETURNS auth.session_return
    LANGUAGE plpgsql
    AS $$
DECLARE
  updated_session auth.session;
BEGIN
  UPDATE auth.session
  SET refreshby = NOW() + INTERVAL '15 minutes'
  WHERE token = p_token
  RETURNING * INTO updated_session;

  IF FOUND THEN
  RETURN (updated_session.token, updated_session.refreshby, updated_session.username)::auth.session_return;
  ELSE
  RETURN NULL;
  END IF;
END;
$$;


ALTER FUNCTION auth.refresh_session(p_token text) OWNER TO postgres;

--
-- TOC entry 226 (class 1255 OID 32771)
-- Name: register_game_server(text); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.register_game_server(p_hostname text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO auth."gameServer" (
        hostname
    )
    VALUES (
        p_hostname
    );
    -- Since there are no known unique constraints, we assume success if the INSERT completes.
    RETURN TRUE;

EXCEPTION
    -- Catch all other exceptions and return FALSE
    WHEN others THEN
        -- RAISE NOTICE 'An error occurred during game server registration: %', SQLERRM;
        RETURN FALSE;
END
$$;


ALTER FUNCTION auth.register_game_server(p_hostname text) OWNER TO postgres;

--
-- TOC entry 228 (class 1255 OID 32773)
-- Name: remove_game_server(text); Type: FUNCTION; Schema: auth; Owner: postgres
--

CREATE FUNCTION auth.remove_game_server(p_hostname text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    DELETE FROM auth."gameServer"
    WHERE hostname = p_hostname;

    -- Check if any row was actually deleted
    IF FOUND THEN
        RETURN TRUE;
    ELSE
        -- No row found with that hostname
        RETURN FALSE;
    END IF;

EXCEPTION
    -- Catch any database exceptions (though unlikely for a simple DELETE)
    WHEN others THEN
        -- RAISE NOTICE 'An error occurred during game server removal: %', SQLERRM;
        RETURN FALSE;
END
$$;


ALTER FUNCTION auth.remove_game_server(p_hostname text) OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16405)
-- Name: keys; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.keys (
    id text NOT NULL,
    owner text NOT NULL,
    key text NOT NULL,
    description text NOT NULL
);


ALTER TABLE auth.keys OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16415)
-- Name: user; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth."user" (
    id text NOT NULL,
    name text NOT NULL
);


ALTER TABLE auth."user" OWNER TO postgres;

--
-- TOC entry 3391 (class 0 OID 24577)
-- Dependencies: 222
-- Data for Name: gameServer; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth."gameServer" (hostname) FROM stdin;
581d1b695857:8000
\.


--
-- TOC entry 3389 (class 0 OID 16405)
-- Dependencies: 220
-- Data for Name: keys; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.keys (id, owner, key, description) FROM stdin;
\.


--
-- TOC entry 3388 (class 0 OID 16395)
-- Dependencies: 219
-- Data for Name: session; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth.session (token, owner, refreshby, username) FROM stdin;
7b65401d-4541-484b-9c13-751d79acb30d	\N	2025-11-11 23:13:57.014561+00	xTrot
c1b8b8e0-0047-4fe5-8706-1bdde9508e20	\N	2025-11-11 23:59:34.756113+00	xTrot
832128f3-852d-48ef-8973-7e97cad2a293	\N	2025-11-12 00:09:00.248611+00	xTrot
5b17e254-b8be-4ddb-af8a-fee2690baee1	\N	2025-11-12 00:13:27.304587+00	xTrot
fe4fd464-a972-4d2a-934f-61e3e0922d95	\N	2025-11-12 00:26:40.194675+00	xTrot
9befea2b-63a8-4773-ba46-3d36bbde100d	\N	2025-11-12 00:27:06.260457+00	xTrot
78ad9bef-128e-49b3-9384-8fba4053d5b5	\N	2025-11-12 00:52:35.987488+00	xTrot
12f186f3-9306-4003-8c2b-22212184b330	\N	2025-11-12 00:52:55.128859+00	xTrot
a9d988b9-80c5-4234-9ab4-19f32ff227a7	\N	2025-11-12 01:46:45.690673+00	xTrot
c06b1c4e-aff2-430e-be01-b52445c163f1	\N	2025-11-12 12:06:55.099922+00	xTrot
20b0cfcc-dce6-4cc5-a522-3e0ccc615f77	\N	2025-11-13 02:05:28.628588+00	xTrot
1db52cd2-c81c-4a84-867c-c5846054d4a2	\N	2025-11-14 00:35:22.050793+00	xTrot
c7be8839-e409-4ebe-ac56-5b28205306cb	\N	2025-11-14 01:26:52.458266+00	xTrot
896aa2b1-0489-4d40-b104-9e31850d6246	\N	2025-11-14 13:02:20.31957+00	xTrot
770e42a4-0633-4fba-abf1-e58c005f604b	\N	2025-11-14 13:06:54.060529+00	xTrot
f38fcc09-7419-45ef-827c-83653aad5a9b	\N	2025-11-14 13:18:32.932994+00	xTrot
390b5320-61e1-448e-a5fb-c8d8b6ae366e	\N	2025-11-14 13:18:53.809274+00	xTrot
2e0dbd55-4642-4021-aea7-c6016f67bfbd	\N	2025-11-14 13:34:30.798893+00	xTrot
256e86b4-6881-496f-800d-fc85ede2a7e2	\N	2025-11-14 14:27:11.986363+00	xtrot
e5f04b68-09ca-4cbb-b3e8-ee23b124d2e1	\N	2025-11-14 14:35:13.775699+00	xTrot
db461587-3334-44d2-9c0e-fbdf282bba0e	\N	2025-11-14 14:40:53.289182+00	xtrot
79bfc971-b5c9-4685-9e64-062b252c1b40	\N	2025-11-14 14:43:56.524012+00	xtrot
09fac1f2-5d55-489a-97c8-15c0ea0db787	\N	2025-11-14 14:58:07.084646+00	xTrot
50799dde-b855-43fe-a504-fd61a7600f1b	\N	2025-11-14 15:02:56.127217+00	xTrot
04e1b86d-5344-45d8-8007-a7de94b67a36	\N	2025-11-14 15:05:58.805638+00	xTrot
8d92d7ca-895c-42e8-b89f-3c26178e76ed	\N	2025-11-14 15:21:33.895312+00	xtrot
1ea1d09a-b2ed-46b8-a0d9-fbd8d09e1e44	\N	2025-11-14 16:04:26.131635+00	xTrot
a713c5fd-de5b-4f15-8c87-ed4ad93d3602	\N	2025-11-14 22:34:12.496822+00	xTrot
34eab376-10cb-4a8e-bbc7-3198af1c0f2f	\N	2025-11-14 22:49:50.621476+00	xTrot
1ef1b3d4-617a-4e0e-83cf-f0da2704b759	\N	2025-11-14 23:10:21.953308+00	xTrot
d6e36ce4-c656-4234-a2ef-0aa80aef0bd7	\N	2025-11-14 23:55:45.196078+00	xTrot
5c72e4c4-bc3f-48bd-badd-52544fb62449	\N	2025-11-15 00:22:07.427743+00	xTrot
3e38044c-8599-49d0-ab11-30a9244ef69e	\N	2025-11-15 00:42:54.841542+00	xTrot
fc8b6073-a513-4ddc-9e3a-55ff77616db2	\N	2025-11-15 00:43:32.173245+00	xtrot
dd01e48e-6294-463e-ad22-7779b466595d	\N	2025-11-15 00:44:42.145917+00	xTrot
842a20b0-4df6-4208-9ee9-cb5ae689e75e	\N	2025-11-15 01:55:07.969225+00	xTrot
fbbc3692-d727-4b6f-a42a-f8c9effe39d6	\N	2025-11-15 04:39:22.637082+00	xTrot
dcdb3603-b745-42da-9aa8-92907b0c5184	\N	2025-11-15 04:39:44.195924+00	xTrot
c9b3723c-798f-41f0-b29f-dbb46a6fcbb0	\N	2025-11-15 04:48:07.729023+00	xtrot
24727777-5dc4-4beb-a545-ac6b58b1c6f4	\N	2025-11-15 04:58:47.936734+00	xTrot
2f31bc59-5e43-4941-bcd1-c6abb5fa1cd3	\N	2025-11-15 04:59:08.960629+00	xTrot
750e6ae1-c449-4a55-bb25-f067539cd36f	\N	2025-11-15 13:13:52.879378+00	xTrot
37c33e57-e0a3-4ed1-8470-14360d996c71	\N	2025-11-15 13:31:26.556601+00	xTrot
5b51f8cc-b832-45a0-a32c-b7f5389050ea	\N	2025-11-15 13:34:11.152661+00	xTrot
a2f4556e-a1e0-40a5-900b-c10306fb1d3c	\N	2025-11-15 13:34:15.653151+00	bsMan
16f53b4d-09bc-453d-ba4d-1d57a3e60b20	\N	2025-11-15 13:56:33.44275+00	xTrot
1104181f-1929-4235-86c6-e3d44bc51f6a	\N	2025-11-15 13:56:36.702114+00	bsMan
\.


--
-- TOC entry 3390 (class 0 OID 16415)
-- Dependencies: 221
-- Data for Name: user; Type: TABLE DATA; Schema: auth; Owner: postgres
--

COPY auth."user" (id, name) FROM stdin;
\.


--
-- TOC entry 3238 (class 2606 OID 16423)
-- Name: keys keys_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.keys
    ADD CONSTRAINT keys_pkey PRIMARY KEY (id);


--
-- TOC entry 3236 (class 2606 OID 16427)
-- Name: session token; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.session
    ADD CONSTRAINT token PRIMARY KEY (token);


--
-- TOC entry 3240 (class 2606 OID 16429)
-- Name: user user_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- TOC entry 3234 (class 1259 OID 16430)
-- Name: fki_owner; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX fki_owner ON auth.session USING btree (owner);


--
-- TOC entry 3241 (class 2606 OID 16436)
-- Name: session owner; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.session
    ADD CONSTRAINT owner FOREIGN KEY (owner) REFERENCES auth."user"(id) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3242 (class 2606 OID 16441)
-- Name: keys owner; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.keys
    ADD CONSTRAINT owner FOREIGN KEY (owner) REFERENCES auth."user"(id) NOT VALID;


-- Completed on 2025-11-15 15:37:46

--
-- PostgreSQL database dump complete
--

