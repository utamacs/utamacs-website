-- ═══════════════════════════════════════════════════════════════
-- 009_community.sql
-- Community posts, reactions, marketplace listings
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE community_posts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id),
  author_id       uuid NOT NULL REFERENCES auth.users(id),
  unit_id         uuid REFERENCES units(id),
  category        text NOT NULL DEFAULT 'General'
                  CHECK (category IN ('General','Help','Lost_Found','Recommendation','Alert')),
  title           text NOT NULL,
  body            text,
  images          text[],
  is_pinned       boolean NOT NULL DEFAULT false,
  is_published    boolean NOT NULL DEFAULT true,
  is_moderated    boolean NOT NULL DEFAULT false,
  moderated_by    uuid REFERENCES auth.users(id),
  moderation_note text,
  view_count      int NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE post_comments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     uuid NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  author_id   uuid NOT NULL REFERENCES auth.users(id),
  body        text NOT NULL,
  parent_id   uuid REFERENCES post_comments(id),
  is_hidden   boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE post_reactions (
  post_id         uuid NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users(id),
  reaction_type   text NOT NULL DEFAULT 'like'
                  CHECK (reaction_type IN ('like','helpful')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE marketplace_listings (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id),
  seller_id           uuid NOT NULL REFERENCES auth.users(id),
  unit_id             uuid REFERENCES units(id),
  category            text NOT NULL
                      CHECK (category IN ('Electronics','Furniture','Books',
                                          'Vehicles','Services','Baby_Items','Other')),
  title               text NOT NULL,
  description         text,
  price               numeric(10,2),
  images              text[],
  status              text NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active','sold','expired','removed')),
  contact_preference  text NOT NULL DEFAULT 'in_app'
                      CHECK (contact_preference IN ('in_app','phone')),
  expires_at          timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_posts_updated_at
  BEFORE UPDATE ON community_posts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_listings_updated_at
  BEFORE UPDATE ON marketplace_listings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Indexes
CREATE INDEX idx_posts_society ON community_posts(society_id, is_published, created_at DESC);
CREATE INDEX idx_posts_author ON community_posts(author_id);
CREATE INDEX idx_post_comments_post ON post_comments(post_id, created_at);
CREATE INDEX idx_listings_society ON marketplace_listings(society_id, status);
