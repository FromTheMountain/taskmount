create sequence "public"."labels_id_seq";


  create table "public"."labels" (
    "id" bigint not null default nextval('public.labels_id_seq'::regclass),
    "name" text not null,
    "color" text
      );



  create table "public"."todo_labels" (
    "todo_id" bigint not null,
    "label_id" bigint not null
      );


alter sequence "public"."labels_id_seq" owned by "public"."labels"."id";

CREATE UNIQUE INDEX labels_name_key ON public.labels USING btree (name);

CREATE UNIQUE INDEX labels_pkey ON public.labels USING btree (id);

CREATE UNIQUE INDEX todo_labels_pkey ON public.todo_labels USING btree (todo_id, label_id);

alter table "public"."labels" add constraint "labels_pkey" PRIMARY KEY using index "labels_pkey";

alter table "public"."todo_labels" add constraint "todo_labels_pkey" PRIMARY KEY using index "todo_labels_pkey";

alter table "public"."labels" add constraint "labels_name_key" UNIQUE using index "labels_name_key";

alter table "public"."todo_labels" add constraint "todo_labels_label_id_fkey" FOREIGN KEY (label_id) REFERENCES public.labels(id) ON DELETE CASCADE not valid;

alter table "public"."todo_labels" validate constraint "todo_labels_label_id_fkey";

alter table "public"."todo_labels" add constraint "todo_labels_todo_id_fkey" FOREIGN KEY (todo_id) REFERENCES public.todos(id) ON DELETE CASCADE not valid;

alter table "public"."todo_labels" validate constraint "todo_labels_todo_id_fkey";

grant delete on table "public"."labels" to "anon";

grant insert on table "public"."labels" to "anon";

grant references on table "public"."labels" to "anon";

grant select on table "public"."labels" to "anon";

grant trigger on table "public"."labels" to "anon";

grant truncate on table "public"."labels" to "anon";

grant update on table "public"."labels" to "anon";

grant delete on table "public"."labels" to "authenticated";

grant insert on table "public"."labels" to "authenticated";

grant references on table "public"."labels" to "authenticated";

grant select on table "public"."labels" to "authenticated";

grant trigger on table "public"."labels" to "authenticated";

grant truncate on table "public"."labels" to "authenticated";

grant update on table "public"."labels" to "authenticated";

grant delete on table "public"."labels" to "service_role";

grant insert on table "public"."labels" to "service_role";

grant references on table "public"."labels" to "service_role";

grant select on table "public"."labels" to "service_role";

grant trigger on table "public"."labels" to "service_role";

grant truncate on table "public"."labels" to "service_role";

grant update on table "public"."labels" to "service_role";

grant delete on table "public"."todo_labels" to "anon";

grant insert on table "public"."todo_labels" to "anon";

grant references on table "public"."todo_labels" to "anon";

grant select on table "public"."todo_labels" to "anon";

grant trigger on table "public"."todo_labels" to "anon";

grant truncate on table "public"."todo_labels" to "anon";

grant update on table "public"."todo_labels" to "anon";

grant delete on table "public"."todo_labels" to "authenticated";

grant insert on table "public"."todo_labels" to "authenticated";

grant references on table "public"."todo_labels" to "authenticated";

grant select on table "public"."todo_labels" to "authenticated";

grant trigger on table "public"."todo_labels" to "authenticated";

grant truncate on table "public"."todo_labels" to "authenticated";

grant update on table "public"."todo_labels" to "authenticated";

grant delete on table "public"."todo_labels" to "service_role";

grant insert on table "public"."todo_labels" to "service_role";

grant references on table "public"."todo_labels" to "service_role";

grant select on table "public"."todo_labels" to "service_role";

grant trigger on table "public"."todo_labels" to "service_role";

grant truncate on table "public"."todo_labels" to "service_role";

grant update on table "public"."todo_labels" to "service_role";


