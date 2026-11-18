-- Residual B1-bis de leona-lia (apéndice de docs/security/D17-D18-review.md).
-- El trigger hacía coalesce(short_display_name(x), x): si la derivación daba null se guardaba el texto tal
-- cual ("M 612345678", "pepe(at)gmail.com", "pepe.garcia.gmail.com") y se publicaba como author_name.
--
-- Regla nueva de la primera palabra (el nombre) en guide.short_display_name:
--   · solo letras unicode ([[:alpha:]]) y los separadores propios de nombres: apóstrofo (' ’ ʼ),
--     guion, punto volado catalán (·) y '/' (para el valor por defecto "Escalador/a");
--   · al menos una letra; sin dígitos, sin '.', sin paréntesis ni '@'/'＠'/'﹫' en ningún sitio del valor.
--   Así una palabra con aspecto de email, dominio o teléfono no pasa como nombre. Las demás palabras
--   solo aportan la inicial (primera letra), así que no pueden filtrar el resto del texto.
--   El resultado sigue debiendo tener ≥ 2 caracteres ("M 612345678" → "M" → null).
-- El trigger rechaza con 23514 cuando la derivación da null (y el valor no es null).
-- submit_user_review no cambia: ya hace coalesce(short_display_name(sanitize(...)), 'Escalador/a'),
-- así que con nombres de Google raros cae a "Escalador/a" y nunca llega al rechazo del trigger.
-- Antes de aplicar: 0 filas en guide.user_profiles (ninguna puede violar la regla).

create or replace function guide.short_display_name(p_name text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_words   text[];
  v_first   text;
  v_initial text;
  v_word    text;
  i         integer;
begin
  if p_name is null or p_name ~ '[@＠﹫]' then
    return null;
  end if;
  v_words := regexp_split_to_array(
    regexp_replace(normalize(p_name, nfc), '^\s+|\s+$', '', 'g'), '\s+');
  v_first := v_words[1];
  if v_first is null or v_first = ''
     or v_first !~ '^[[:alpha:]''’ʼ·/-]+$'
     or v_first !~ '[[:alpha:]]' then
    return null;
  end if;

  if v_first = upper(v_first) or v_first = lower(v_first) then
    v_first := initcap(lower(v_first));
  end if;
  v_first := left(v_first, 36);

  for i in 2 .. coalesce(array_length(v_words, 1), 1) loop
    v_word := v_words[i];
    continue when lower(v_word) in ('de', 'del', 'la', 'las', 'los', 'el', 'y', 'i', 'e',
                                    'da', 'das', 'do', 'dos', 'di', 'du', 'van', 'von', 'der', 'den', 'le', 'ter');
    v_initial := substring(v_word from '[[:alpha:]]');
    exit when v_initial is not null;
  end loop;

  v_first := v_first || coalesce(' ' || upper(v_initial) || '.', '');
  if char_length(v_first) < 2 then
    return null;
  end if;
  return v_first;
end;
$$;
revoke execute on function guide.short_display_name(text) from public;

create or replace function guide.user_profiles_short_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_short text;
begin
  if new.display_name is null then
    return new;
  end if;
  if new.display_name ~ '[@＠﹫]' then
    raise exception 'display_name must not contain @' using errcode = '23514';
  end if;
  v_short := guide.short_display_name(new.display_name);
  if v_short is null then
    raise exception 'display_name is not a valid name' using errcode = '23514';
  end if;
  new.display_name := v_short;
  return new;
end;
$$;
revoke execute on function guide.user_profiles_short_name() from public, anon, authenticated;
