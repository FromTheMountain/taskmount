create sequence "public"."todos_id_seq";

alter table "public"."todos" alter column "id" set default nextval('public.todos_id_seq'::regclass);

alter table "public"."todos" alter column "id" set data type bigint using "id"::bigint;

alter sequence "public"."todos_id_seq" owned by "public"."todos"."id";

CREATE UNIQUE INDEX todos_pkey ON public.todos USING btree (id);

alter table "public"."todos" add constraint "todos_pkey" PRIMARY KEY using index "todos_pkey";


