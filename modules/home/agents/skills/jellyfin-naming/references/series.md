# TV series

Library type: **Shows**. Source: <https://jellyfin.org/docs/general/server/media/shows>

## Layout

Series folder → season folders → episode files. Do not put episodes in the series root if season folders exist. Do not put episodes in the library root.

```text
Shows/
  Series Name A (2010)/
    Season 00/
      Some Special.mkv
      Series Name A S00E01.mkv
    Season 01/
      Series Name A S01E01-E02.mkv
      Series Name A S01E03.mkv
    Season 02/
      Series Name A S02E01.mkv
      Series Name A S02E03 Part 1.mkv
      Series Name A S02E03 Part 2.mkv
  Series Name B (2018) [tvdbid-79168]/
    Season 01/
      Series Name B S01E01.mkv
      Series Name B S01E02.mkv
```

## Series folder

```text
Series Name (year) [metadata provider id]
```

Same optional year / ID rules as movies. TVDB is the show-specific provider: `[tvdbid-79168]`. TMDB and IMDB IDs are also valid.

## Season folders

- Name them `Season *` - **never** `S01`, `SE01`, `Season1`.
- Pad so every season has the same width: `Season 05`, not `Season 5` next to `Season 10`.
- Specials: `Season 00`.
- One numbering scheme per show. Do not mix `Season 1` and `Season 01`.

## Episodes

Preferred:

```text
Series Name S01E01.mkv
Series Name S01E01 Episode Title.mkv
Series Name (2021) S01E01 Title.mkv
```

| Case | Pattern |
| --- | --- |
| Single episode | `S01E01` |
| Multi-episode file | `S01E01-E02` |
| Specials | files in `Season 00`; prefer a descriptive name if the provider has no special metadata |
| Stacked parts of one episode | `S01E01-part-1.mkv` (see [shared.md](shared.md#multiple-parts)) |
| Title happens to say "Part 1" | `S02E03 Part 1.mkv` - this is **not** stacking |

A multi-episode file (`S01E01-E02`) is shown as one entry with combined metadata. Prefer splitting with MKVToolNix only if the user asked.

External subs/audio use the full episode basename: `Series Name S01E01 Title.en.srt`.

## From a typical download

```text
Show.Name.S02E04.1080p.WEB.h264-GROUP.mkv
Show.Name.S02E04.1080p.WEB.h264-GROUP.srt
```

becomes

```text
Shows/Show Name (2018) [tvdbid-123]/
  Season 02/
    Show Name S02E04.mkv
    Show Name S02E04.en.srt
```

Drop quality/group tags. Keep a real episode title only when you know it; do not copy `1080p WEB` into the title.

## Specials

- Default location: `Season 00`.
- If the provider will not match `S00E01`, use a descriptive filename instead of a fake episode number.
- Showing a special inside another season needs Jellyfin metadata (`airsbefore_season` / `airsafter_season` / `airsbefore_episode`) plus the dashboard option "Display specials within their series they aired in". Naming alone cannot do that.

## Extras, 3D, images

Same extras folders/suffixes as movies, at series **or** season level ([shared.md](shared.md#extras)).

Episode thumb: `Series Name S01E01-thumb.jpg`.

Season / series images (`cover.jpg`, `backdrop.jpg`, `logo.png`) sit in that folder, not next to a single episode, unless they are episode thumbs.

## Move checklist

1. Resolve series title + year + TVDB/TMDB/IMDB id.
2. Create `Shows/<Series (year) [id]>/Season NN/`.
3. Normalize `1x04`, `s2e4`, `Season 2 Episode 4` → `S02E04`.
4. `mv` episode + sidecars into that season folder.
5. Specials go to `Season 00`, not a random extras folder.
6. Refuse to leave a stray episode beside `Season 01/`.
