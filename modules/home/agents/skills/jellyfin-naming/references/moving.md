# Moving media

## Workflow

1. **Classify** each item as movie, series episode, or music. If mixed or unclear, stop and ask.
2. **Read the type reference.** Do not improvise episode or version syntax.
3. **Identify** title, year, and IDs from the current name, embedded tags, or a metadata lookup. Confirm ambiguous titles with the user.
4. **Sanitize** every path component ([shared.md](shared.md#forbidden-characters)).
5. **Print a dry-run table**: `from → to` for every file that will move, including sidecars. Wait for approval if the set is large, destructive, or the destination already has content.
6. **Create destination dirs, then `mv`.** Keep video + sidecars atomic per item.
7. **Verify** the tree matches the template below. Report leftovers and anything skipped.

## Target templates

```text
Movies/
  Movie Name (2019) [tmdbid-12345]/
    Movie Name (2019) [tmdbid-12345].mkv
    Movie Name (2019) [tmdbid-12345].en.srt

Shows/
  Series Name (2018) [tvdbid-79168]/
    Season 01/
      Series Name S01E01 Episode Title.mkv
      Series Name S01E01 Episode Title.en.srt
    Season 00/
      Holiday Special.mkv

Music/
  Artist Name/
    Album Name (2020)/
      01 Track Title.flac
      01 Track Title.lrc
      cover.jpg
    folder.jpg
```

Spaces are preferred over underscores. Match the provider title, not the torrent name.

## Classify incoming files

Treat the **library type** as authoritative if the user already pointed at a Movies / Shows / Music root.

| Clue | Type |
| --- | --- |
| `S01E02`, `1x02`, `Season 1`, `s01e02-e03` | Series |
| Single feature + year, no season/episode | Movie |
| Audio (`flac`/`mp3`/`m4a`/`ogg`/`opus`) grouped as an album | Music |
| `.mp4` that is audio-only | Music - rename to `.m4a` first |
| Several video files that are clearly the same title at different resolutions | Movie versions, one folder |
| `VIDEO_TS/` or `BDMV/` | Movie disc folder; no versions, parts, or external tracks |

Ask when a file could be a movie *or* a special, a concert film, or an album of mixed artists.

## Rename and move

```bash
mkdir -p -- "$dest_dir"
mv -n -- "$src" "$dest"
```

- `-n` / `--no-clobber`: refuse overwrites.
- Recreate the relative sidecar set next to the new basename.
- If only the file needs renaming inside an already-correct folder, `mv` in place.
- If the parent folder name is wrong, rename the folder **and** every media file whose basename must match it.
- Preserve the original extension unless the music container rules require a rename (`.mp4` → `.m4a`, `.mkv`/`.webm`/`.weba` → `.mka`).

Dry-run first when more than a handful of items move:

```bash
printf '%s -> %s\n' "$src" "$dest"
```

Do not copy-then-delete as a default. `mv` on the same filesystem is enough.

## Sidecars

Anything that shares the media basename, plus extras/image folders, must follow the media file.

| Kind | Pattern |
| --- | --- |
| Subtitles / external audio | `Name.<flags>.<lang>.srt` - see [shared.md](shared.md#external-subtitles-and-audio) |
| NFO | `Name.nfo` |
| Episode thumb | `Name-thumb.jpg` |
| Lyrics | `Track.lrc` / `.elrc` / `.txt` |
| Images | `cover.jpg`, `folder.jpg`, `backdrop.jpg`, `logo.png` |
| Extras | `trailers/`, `featurettes/`, `behind the scenes/`, … |

When the media basename changes, rename matching sidecars to the new basename. Do not leave `oldname.en.srt` beside `New Name (2019).mkv`.

## What to look up

For movies and shows, prefer:

```text
Title (year) [tmdbid-123] [imdbid-tt1234567]
Title (year) [tvdbid-79168]
```

- TMDB id is the numeric path segment: `themoviedb.org/movie/569094-…` → `[tmdbid-569094]`
- IMDB: `imdb.com/title/tt9362722/` → `[imdbid-tt9362722]`
- TVDB (shows): the series id on the show page → `[tvdbid-266189]`

Multiple IDs are allowed. If you cannot verify an id, omit it.

Music identification comes from **embedded tags**, not the filename. If tags are missing or wrong, say so; do not "fix" tags unless asked. If tags are absent, the filename becomes the track title - then name it carefully.

## Verification

After moving, the tree should satisfy:

- Movies: each film is `Movies/<folder>/<folder>.ext` or `Movies/<folder>/<folder> - Label.ext`
- Shows: no episode files live directly under the series folder or the library root; every episode is under `Season NN`
- Music: each directory contains tracks from exactly one album
- No forbidden characters in any new path
- Every subtitle/lyric/nfo that existed still sits next to its media file

Report: moved count, skipped/ambiguous items, and any leftover files in the source.

## Anti-patterns

- Dumping `Movie (2019).mkv` directly in `Movies/` (works sometimes; do not do it - extras, versions, and matching get worse)
- Season folder named `S01`, `Season1`, or `season 1` mixed with `Season 01`
- Episode files at the show root alongside season folders
- Two movies or two albums in one folder
- Version label without ` - ` (`Movie 1080p.mkv` is a *different* movie)
- Version prefix that does not match the folder byte-for-byte
- Using `-cd1` and ` - 1080p` together
- Colon left in a title (`Star Wars: A New Hope` → `Star Wars - A New Hope`)
- Keeping torrent junk in the title (`Movie.2019.1080p.BluRay.x264-GROUP`)
- Treating `.iso` as first-class (unsupported; remux/extract only if the user asked)
- Renaming music purely for cosmetics when tags already identify the tracks
- Leaving `.mp4` audio files in a music library
