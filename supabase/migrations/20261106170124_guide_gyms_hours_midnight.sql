-- Cierre a medianoche en horarios de rocódromos (Freebloc cerraba a 23:59 de apaño).
-- El cierre puede ser exactamente '24:00' (fin del día, 1440 min); la apertura nunca. Sin tramos que crucen la
-- medianoche (22:00-02:00 sigue siendo inválido: cierre <= apertura). Misma firma, inmutable, mismos GRANT.
-- gyms_opening_hours_valid, item_publish_blockers e import_row llaman a esta función: no cambian.
create or replace function guide.opening_hours_valid(p_hours jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  c_open  constant text := '^([01]?[0-9]|2[0-3]):[0-5][0-9]$';
  c_close constant text := '^(([01]?[0-9]|2[0-3]):[0-5][0-9]|24:00)$';
  v_day  text;
  v_val  jsonb;
  v_slot jsonb;
  v_open text;
  v_close text;
begin
  if p_hours is null or jsonb_typeof(p_hours) <> 'object' then
    return false;
  end if;
  for v_day, v_val in select e.key, e.value from jsonb_each(p_hours) e loop
    if v_day not in ('mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun') or jsonb_typeof(v_val) <> 'array'
       or jsonb_array_length(v_val) > 6 then
      return false;
    end if;
    for v_slot in select s from jsonb_array_elements(v_val) s loop
      if jsonb_typeof(v_slot) <> 'array' or jsonb_array_length(v_slot) <> 2
         or jsonb_typeof(v_slot -> 0) <> 'string' or jsonb_typeof(v_slot -> 1) <> 'string' then
        return false;
      end if;
      v_open := v_slot ->> 0;
      v_close := v_slot ->> 1;
      if v_open !~ c_open or v_close !~ c_close then
        return false;
      end if;
      -- '24:00' da 1440 con la misma fórmula.
      if split_part(v_close, ':', 1)::integer * 60 + split_part(v_close, ':', 2)::integer
         <= split_part(v_open, ':', 1)::integer * 60 + split_part(v_open, ':', 2)::integer then
        return false;
      end if;
    end loop;
  end loop;
  return true;
end;
$$;
revoke all on function guide.opening_hours_valid(jsonb) from public, anon;
grant execute on function guide.opening_hours_valid(jsonb) to authenticated, service_role;
