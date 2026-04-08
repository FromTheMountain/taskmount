create table "todos" (
	"id" bigserial primary key,
	"description" text not null,
	"priority" integer not null,
	"completed" timestamp,
	"start_date" timestamp,
	"deadline" timestamp
);

create table "labels" (
  "id" bigserial primary key,
  "name" text not null unique,
  "color" text
);

create table "todo_labels" (
  "todo_id" bigint not null references "todos"("id") on delete cascade,
  "label_id" bigint not null references "labels"("id") on delete cascade,
  primary key ("todo_id", "label_id")
);
