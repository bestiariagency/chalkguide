-- F2.10 re-revisión · N1 y N2 de leona-lia (docs/security/F2.10-guide-review.md).
-- N1: el saneo y los CHECK de nombres también rechazan caracteres bidi y de ancho cero
--     (U+200B–U+200F, U+202A–U+202E, U+2066–U+2069, U+FEFF), que permiten suplantación visual.
-- N2: display_name sin espacios en los extremos y ≤ 40, coherente con author_name.

create or replace function guide.sanitize_display_name(p_name text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text;
begin
  v := regexp_replace(coalesce(p_name, ''),
         '[[:cntrl:]<>"`\\​-‏‪-‮⁦-⁩﻿]', '', 'g');
  v := btrim(regexp_replace(v, '\s+', ' ', 'g'));
  v := btrim(left(v, 40));
  if char_length(v) < 2 then
    return null;
  end if;
  return v;
end;
$$;
revoke execute on function guide.sanitize_display_name(text) from public;

alter table guide.user_profiles drop constraint if exists user_profiles_display_name_safe;
alter table guide.user_profiles
  add constraint user_profiles_display_name_safe check (
    display_name = btrim(display_name)
    and char_length(display_name) between 2 and 40
    and display_name !~ '[[:cntrl:]<>"`\\​-‏‪-‮⁦-⁩﻿]'
  );

alter table guide.user_reviews drop constraint if exists user_reviews_author_name_safe;
alter table guide.user_reviews
  add constraint user_reviews_author_name_safe check (
    author_name = btrim(author_name)
    and char_length(author_name) between 2 and 40
    and author_name !~ '[[:cntrl:]<>"`\\​-‏‪-‮⁦-⁩﻿]'
  );
