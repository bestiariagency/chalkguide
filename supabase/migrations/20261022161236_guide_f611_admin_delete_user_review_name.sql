-- F6.11: nombre acordado con el frontend (admin_delete_user_review). Misma lógica que delete_user_review.
drop function if exists guide.delete_user_review(uuid, text);

create or replace function guide.admin_delete_user_review(p_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item uuid;
begin
  perform guide.assert_admin();
  if p_reason is null or p_reason not in ('erasure_request', 'illegal_content') then
    raise exception 'invalid reason' using errcode = '22023';
  end if;
  select r.item_id into v_item from guide.user_reviews r where r.id = p_id for update;
  if v_item is null then
    raise exception 'review not found' using errcode = 'P0002';
  end if;
  -- Marca atada a la fila: el trigger user_reviews_log_moderation la usa para registrar el motivo.
  perform set_config('guide.review_delete', p_id::text || ':' || p_reason, true);
  delete from guide.user_reviews where id = p_id;
  perform set_config('guide.review_delete', '', true);
  return guide.user_review_item_stats(v_item) || jsonb_build_object('id', p_id, 'deleted', true);
end;
$$;
revoke all on function guide.admin_delete_user_review(uuid, text) from public, anon;
grant execute on function guide.admin_delete_user_review(uuid, text) to authenticated;
