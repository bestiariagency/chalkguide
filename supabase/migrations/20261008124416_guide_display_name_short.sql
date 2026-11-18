-- D17 · Nombre público de opiniones = nombre + inicial del apellido ("Marta G.").
-- guide.short_display_name deriva la forma corta de un nombre ya saneado (no sanea: eso sigue siendo
-- guide.sanitize_display_name + los CHECK de N1/N2). Reglas:
--   · NFC y espacios (incluidos múltiples/NBSP) colapsados; primera palabra = nombre.
--   · Nombre en MAYÚSCULAS o minúsculas completas → Capitalizado (initcap); si viene mixto se respeta (McKenzie).
--   · Inicial = primera letra (unicode) de la siguiente palabra que no sea partícula (de, del, la, van, von…),
--     en mayúscula + punto. Para nombres hispanos "Juan García López" → "Juan G." (primer apellido).
--   · Una sola palabra → solo el nombre. Algo con '@' (email) → null. Resultado < 2 caracteres → null.
--   · Idempotente: short_display_name('Marta G.') = 'Marta G.'.
-- Un trigger BEFORE en user_profiles la aplica siempre, así que el usuario tampoco puede guardar su nombre
-- completo editando su perfil vía PostgREST (SECURITY DEFINER porque short_display_name no es ejecutable por roles API). Si la derivación da null se deja el valor para que decida el CHECK.

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
  if p_name is null then
    return null;
  end if;
  v_words := regexp_split_to_array(
    regexp_replace(normalize(p_name, nfc), '^\s+|\s+$', '', 'g'), '\s+');
  v_first := v_words[1];
  if v_first is null or v_first = '' or strpos(p_name, '@') > 0 then
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
begin
  new.display_name := coalesce(guide.short_display_name(new.display_name), new.display_name);
  return new;
end;
$$;
revoke execute on function guide.user_profiles_short_name() from public;

drop trigger if exists user_profiles_short_name on guide.user_profiles;
create trigger user_profiles_short_name before insert or update of display_name on guide.user_profiles
  for each row execute function guide.user_profiles_short_name();

-- Filas existentes (reales y dummy d0d0d0d0-): el trigger de sincronización propaga a user_reviews.author_name.
update guide.user_profiles
set display_name = guide.short_display_name(display_name)
where guide.short_display_name(display_name) is not null
  and display_name is distinct from guide.short_display_name(display_name);

-- Por si alguna opinión quedó desalineada de su perfil.
update guide.user_reviews r
set author_name = p.display_name
from guide.user_profiles p
where p.user_id = r.user_id and r.author_name is distinct from p.display_name;
