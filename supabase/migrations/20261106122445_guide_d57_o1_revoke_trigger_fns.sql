-- D57 O1 (leona-lia): las funciones de trigger de authors no necesitan EXECUTE para PUBLIC.
revoke all on function guide.authors_before_delete(), guide.authors_require_alt() from public;
