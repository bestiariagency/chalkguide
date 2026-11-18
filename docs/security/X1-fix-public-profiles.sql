-- X1 (F2.10 review): clients could set public.profiles.is_admin on their own row
-- (UPDATE policy "own profile write" + column grants to anon/authenticated), and then
-- read every user's email via get_profiles_with_email().
--
-- Fix: block direct changes to is_admin from client roles. The legitimate path,
-- set_admin_by_email() (SECURITY DEFINER, runs as owner), keeps working.
-- APPLIED 2026-10-05 as migration `public_profiles_protect_is_admin` (with Xavi's approval).
-- Verified in a rolled-back transaction: self-escalation blocked (42501), normal profile
-- edits still work, set_admin_by_email still promotes. Chalk app's repo should keep a copy.

create or replace function public.profiles_protect_is_admin()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.is_admin := false;
  elsif new.is_admin is distinct from old.is_admin then
    raise exception 'is_admin cannot be changed directly' using errcode = '42501';
  end if;

  return new;
end;
$$;

revoke execute on function public.profiles_protect_is_admin() from public, anon, authenticated;

drop trigger if exists profiles_protect_is_admin on public.profiles;
create trigger profiles_protect_is_admin
  before insert or update on public.profiles
  for each row execute function public.profiles_protect_is_admin();
