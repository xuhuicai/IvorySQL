/*-------------------------------------------------------------------------
 * Copyright 2026 IvorySQL Global Development Team
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * utl_recomp--1.0.sql
 *
 * Oracle-compatible UTL_RECOMP package.
 *
 * RECOMP_SERIAL / RECOMP_SCHEMA / RECOMP_PARALLEL revalidate the
 * PL/iSQL/PL/pgSQL/SQL routines and views of a schema by re-executing
 * their definitions through CREATE OR REPLACE (the only way PostgreSQL
 * forces a recompile).  Objects that fail re-validation (missing
 * dependencies, syntax errors recovered from a broken body, etc.) are
 * reported as WARNINGs and do not stop the remaining objects.
 *
 * Semantics differ from Oracle where PostgreSQL requires it:
 * - a NULL schema means the current schema (instead of "all schemas"),
 *   so that a regular user never recompiles objects it cannot own;
 * - the flags argument is accepted for signature compatibility and is
 *   currently ignored;
 * - RECOMP_PARALLEL runs serially; the threads argument is accepted for
 *   compatibility and ignored.
 *
 * AUTHID CURRENT_USER: objects are recompiled under the caller's
 * privileges, so a caller can only recompile objects in schemas where it
 * has CREATE privileges, mirroring Oracle's statement that the package
 * "recompiles database objects with the user's privileges".
 *
 * contrib/ivorysql_ora/src/builtin_packages/utl_recomp/utl_recomp--1.0.sql
 *
 *-------------------------------------------------------------------------
 */

CREATE OR REPLACE PACKAGE utl_recomp AUTHID CURRENT_USER IS

    PROCEDURE recomp_serial(schema IN VARCHAR2 DEFAULT NULL,
                            flags IN INTEGER DEFAULT 0);

    PROCEDURE recomp_parallel(threads IN INTEGER,
                              schema IN VARCHAR2 DEFAULT NULL,
                              flags IN INTEGER DEFAULT 0);

    PROCEDURE recomp_schema(schema IN VARCHAR2 DEFAULT NULL,
                            flags IN INTEGER DEFAULT 0);

END utl_recomp;

CREATE OR REPLACE PACKAGE BODY utl_recomp IS

    /*
     * Recompile every routine (non-C, non-internal language) and every
     * non-materialized view in the given schema.  Each object's definition
     * is regenerated with pg_get_functiondef()/pg_get_viewdef() and
     * re-executed via CREATE OR REPLACE, which forces PostgreSQL to
     * re-parse and re-validate it.
     */
    PROCEDURE recompile_schema_objects(p_schema VARCHAR2,
                                       p_flags INTEGER) IS
        v_schema VARCHAR2 := p_schema;
        r RECORD;
        done int := 0;
        failed int := 0;
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = v_schema) THEN
            RAISE EXCEPTION 'UTL_RECOMP: schema "%" does not exist', v_schema;
        END IF;

        FOR r IN
            SELECT oid::regprocedure AS sig,
                   pg_get_functiondef(oid) AS def
              FROM pg_proc
             WHERE pronamespace = (SELECT oid FROM pg_namespace
                                    WHERE nspname = v_schema)
               AND prokind IN ('f', 'p')
               AND prolang NOT IN (SELECT oid FROM pg_language
                                    WHERE lanname IN ('internal', 'c'))
        LOOP
            BEGIN
                EXECUTE r.def;
                done := done + 1;
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'UTL_RECOMP: could not recompile %: %', r.sig, SQLERRM;
                failed := failed + 1;
            END;
        END LOOP;

        FOR r IN
            SELECT quote_ident(v_schema) || '.' || quote_ident(c.relname) AS qualname,
                   'CREATE OR REPLACE VIEW ' ||
                       quote_ident(v_schema) || '.' || quote_ident(c.relname) ||
                       ' AS ' || pg_get_viewdef(c.oid) AS def
              FROM pg_class c
             WHERE c.relnamespace = (SELECT oid FROM pg_namespace
                                      WHERE nspname = v_schema)
               AND c.relkind = 'v'
        LOOP
            BEGIN
                EXECUTE r.def;
                done := done + 1;
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'UTL_RECOMP: could not recompile %: %', r.qualname, SQLERRM;
                failed := failed + 1;
            END;
        END LOOP;

        RAISE NOTICE 'UTL_RECOMP: recompiled % objects in schema "%" (% failed)',
                     done, v_schema, failed;
    END;

    PROCEDURE recomp_serial(schema IN VARCHAR2 DEFAULT NULL,
                            flags IN INTEGER DEFAULT 0) IS
    BEGIN
        recompile_schema_objects(COALESCE(schema, current_schema()::text), flags);
    END;

    PROCEDURE recomp_parallel(threads IN INTEGER,
                              schema IN VARCHAR2 DEFAULT NULL,
                              flags IN INTEGER DEFAULT 0) IS
    BEGIN
        IF threads <= 0 THEN
            RAISE EXCEPTION 'UTL_RECOMP: threads must be a positive integer';
        END IF;
        recompile_schema_objects(COALESCE(schema, current_schema()::text), flags);
    END;

    PROCEDURE recomp_schema(schema IN VARCHAR2 DEFAULT NULL,
                            flags IN INTEGER DEFAULT 0) IS
    BEGIN
        recompile_schema_objects(COALESCE(schema, current_schema()::text), flags);
    END;

END utl_recomp;