create table if not exists public.keep_alive (
  id bigint primary key,
  updated_at timestamptz not null default now()
);

alter table public.keep_alive enable row level security;

drop policy if exists "anon_read_keep_alive" on public.keep_alive;
create policy "anon_read_keep_alive"
on public.keep_alive for select
to anon
using (true);

drop policy if exists "anon_insert_keep_alive" on public.keep_alive;
create policy "anon_insert_keep_alive"
on public.keep_alive for insert
to anon
with check (true);

drop policy if exists "anon_update_keep_alive" on public.keep_alive;
create policy "anon_update_keep_alive"
on public.keep_alive for update
to anon
using (true)
with check (true);

insert into public.keep_alive (id, updated_at)
values (1, now())
on conflict (id) do update set updated_at = now();
