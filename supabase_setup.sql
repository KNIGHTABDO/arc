-- =========================================================
-- ARC (DebridUI) Database Initialization Script
-- Consolidated from migrations: 0000, 0001, 0002, 0003
-- =========================================================

-- 1. Create Core Tables
CREATE TABLE "user" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"email" text NOT NULL,
	"email_verified" boolean DEFAULT false NOT NULL,
	"image" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "user_email_unique" UNIQUE("email")
);

CREATE TABLE "addons" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"name" text NOT NULL,
	"url" text NOT NULL,
	"enabled" boolean DEFAULT true NOT NULL,
	"order" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "addons_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action,
    CONSTRAINT "unique_user_order" UNIQUE ("user_id", "order") DEFERRABLE INITIALLY IMMEDIATE
);

CREATE TABLE "user_accounts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"api_key" text NOT NULL,
	"type" text NOT NULL,
	"name" text NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
    CONSTRAINT "user_accounts_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action
);

CREATE TABLE "user_settings" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"settings" jsonb NOT NULL,
    CONSTRAINT "user_settings_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action
);

CREATE TABLE "account" (
	"id" text PRIMARY KEY NOT NULL,
	"account_id" text NOT NULL,
	"provider_id" text NOT NULL,
	"user_id" uuid NOT NULL,
	"access_token" text,
	"refresh_token" text,
	"id_token" text,
	"access_token_expires_at" timestamp,
	"refresh_token_expires_at" timestamp,
	"scope" text,
	"password" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp NOT NULL,
    CONSTRAINT "account_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action
);

CREATE TABLE "session" (
	"id" text PRIMARY KEY NOT NULL,
	"expires_at" timestamp NOT NULL,
	"token" text NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp NOT NULL,
	"ip_address" text,
	"user_agent" text,
	"user_id" uuid NOT NULL,
	CONSTRAINT "session_token_unique" UNIQUE("token"),
    CONSTRAINT "session_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action
);

CREATE TABLE "verification" (
	"id" text PRIMARY KEY NOT NULL,
	"identifier" text NOT NULL,
	"value" text NOT NULL,
	"expires_at" timestamp NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);

CREATE TABLE "playback_history" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"imdb_id" text NOT NULL,
	"type" text NOT NULL,
	"title" text NOT NULL,
	"year" integer,
	"poster_url" text,
	"season" integer,
	"episode" integer,
	"updated_at" timestamp DEFAULT now() NOT NULL,
    CONSTRAINT "playback_history_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action
);

-- 2. Create Optimized Indexes
CREATE INDEX "addons_userId_idx" ON "addons" USING btree ("user_id");
CREATE UNIQUE INDEX "unique_user_account" ON "user_accounts" USING btree ("user_id","api_key","type");
CREATE INDEX "user_accounts_userId_idx" ON "user_accounts" USING btree ("user_id");
CREATE INDEX "account_userId_idx" ON "account" USING btree ("user_id");
CREATE INDEX "session_userId_idx" ON "session" USING btree ("user_id");
CREATE INDEX "verification_identifier_idx" ON "verification" USING btree ("identifier");
CREATE INDEX "playback_history_user_updated_idx" ON "playback_history" USING btree ("user_id","updated_at" DESC NULLS LAST);
CREATE UNIQUE INDEX "playback_history_user_imdb_idx" ON "playback_history" USING btree ("user_id","imdb_id");
CREATE INDEX "playback_history_imdb_idx" ON "playback_history" USING btree ("imdb_id");

-- 3. Create Playback History Cleanup Logic
CREATE OR REPLACE FUNCTION enforce_playback_history_limit()
RETURNS TRIGGER AS $$
BEGIN
    WITH entries_to_delete AS (
        SELECT id
        FROM playback_history
        WHERE user_id = NEW.user_id
        ORDER BY updated_at DESC
        OFFSET 20
    )
    DELETE FROM playback_history
    WHERE id IN (SELECT id FROM entries_to_delete);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER playback_history_cleanup_trigger
    AFTER INSERT ON playback_history
    FOR EACH ROW
    EXECUTE FUNCTION enforce_playback_history_limit();

-- 4. Add Documentation Comments
COMMENT ON FUNCTION enforce_playback_history_limit() IS 'Maintains max 20 playback history entries per user';
COMMENT ON TRIGGER playback_history_cleanup_trigger ON playback_history IS 'Automatically triggers cleanup on new playback records';

-- 5. Enable RLS (Explicitly quoted to prevent syntax errors)
ALTER TABLE "user" ENABLE ROW LEVEL SECURITY;
