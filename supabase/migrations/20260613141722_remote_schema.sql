drop extension if exists "pg_net";

alter table "public"."labels" enable row level security;

alter table "public"."todo_labels" enable row level security;

alter table "public"."todos" enable row level security;


  create policy "Enable for authenticated users only"
  on "public"."labels"
  as permissive
  for all
  to authenticated
using (true)
with check (true);



  create policy "Enable for authenticated users only"
  on "public"."todo_labels"
  as permissive
  for all
  to authenticated
using (true);



  create policy "Only authenticated users"
  on "public"."todos"
  as permissive
  for all
  to authenticated
using (true);



