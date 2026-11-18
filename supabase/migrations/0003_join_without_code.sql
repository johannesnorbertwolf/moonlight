-- Moonlight: join without a group code while there is only one group (the trial).
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.
--
-- join_group now accepts an empty code: it then joins the only group. With more than one group
-- the code is required again. Codes stay in the table, so they can come back later.

create or replace function public.join_group(p_code text, p_name text, p_goal time, p_platform text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  g public.groups;
  pid uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if coalesce(trim(p_code), '') = '' then
    if (select count(*) from public.groups) <> 1 then
      raise exception 'unknown group code' using errcode = 'P0002';
    end if;
    select * into g from public.groups limit 1;
  else
    select * into g from public.groups where join_code = upper(trim(p_code));
  end if;
  if g.id is null then raise exception 'unknown group code' using errcode = 'P0002'; end if;

  -- Leave any previous link of this browser.
  update public.participants set auth_user = null where auth_user = auth.uid();

  insert into public.participants (group_id, auth_user, name, goal_start, platform)
  values (g.id, auth.uid(), trim(p_name), p_goal, p_platform)
  on conflict (group_id, name) do update
    set auth_user = excluded.auth_user, goal_start = excluded.goal_start, platform = excluded.platform
  returning id into pid;
  return pid;
end;
$$;
