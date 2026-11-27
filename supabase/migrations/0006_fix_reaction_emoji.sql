-- Moonlight: fix the reaction emoji check.
-- The check from 0002 came out wrong in the live database (the emojis didn't survive being pasted
-- into the dashboard), so every reaction, even 🌙, failed with reactions_emoji_check.
-- This rebuilds it from Unicode code points, which survive any copy and paste.
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.

alter table public.reactions drop constraint if exists reactions_emoji_check;

alter table public.reactions add constraint reactions_emoji_check check (emoji in (
  chr(127769),               -- 🌙
  chr(128079),               -- 👏
  chr(128293),               -- 🔥
  chr(128564),               -- 😴
  chr(10084) || chr(65039),  -- ❤️
  chr(10084),                -- ❤ (without the emoji variation selector)
  chr(128716),               -- 🛌
  chr(129417),               -- 🦉
  chr(129445),               -- 🦥
  chr(129393)                -- 🥱
));
