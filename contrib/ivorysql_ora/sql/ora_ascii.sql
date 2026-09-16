--
-- ora_ascii.sql: test ASCII function
--
--
select ascii(321) from dual;

select ascii(213.3f) from dual;

select ascii(123.4d) from dual;

select ascii('abc') from dual;

select ascii('xyz') from dual;

select ascii(to_char('2026-01-01'::date,'DD-MON-YYYY HH24:MI:SS')) from dual;

select ascii(to_char('2026-01-11 01:02:03.00'::timestamp,'DD-MON-YYYY HH24:MI:SS.FF6')) from dual;

select ascii(to_char('2026-01-22 01:02:03.00 +01:00'::timestamptz,'DD-MON-YYYY HH24:MI:SS TZH:TZM')) from dual;

select ascii('') is null from dual;

-- multibyte input: ASCII returns the code point of the first character,
-- not the value of its first byte (Oracle semantics).
select ascii('中') from dual;

select ascii('中'::varchar2) from dual;

select ascii('中'::oravarcharchar) from dual;

select ascii('中'::oravarcharbyte) from dual;

select ascii('中'::oracharchar) from dual;

select ascii('中'::text) from dual;

-- only the first character is examined
select ascii('中abc') from dual;

-- supplementary-plane character (U+20000) needs a 4-byte UTF-8 sequence
select ascii('𠀀') from dual;

select ascii(null) is null from dual;