-- A split's colour (15 Oct 2026): a SplitColor name such as 'blue', or null for the default emerald.
-- The app tints trained days on Home, Profile and the widgets with the colour of the split trained.
alter table public.gb_splits
  add column if not exists color text check (color is null or char_length(color) between 1 and 20);
