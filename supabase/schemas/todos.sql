create table "todos" (
	"id" bigserial primary key,
	"description" text not null,
	"priority" integer not null,
	"completed" timestamp,
	"start_date" timestamp,
	"deadline" timestamp
);
