# Shared Jellyfin naming rules

Applies to movies, shows, and music unless a type reference says otherwise.

Source: [Movies](https://jellyfin.org/docs/general/server/media/movies), [TV Shows](https://jellyfin.org/docs/general/server/media/shows), [Music](https://jellyfin.org/docs/general/server/media/music), [Identifiers](https://jellyfin.org/docs/general/server/metadata/identifiers).

## Forbidden characters

These **will** break matching if they appear in a file or folder name:

```text
< > : " / \ | ? *
```

House replacements when the provider title contains them:

| Character | Replace with |
| --- | --- |
| `:` | ` - ` (subtitle separator) |
| `/` `\` | ` - ` or space |
| `?` | drop it |
| `*` | drop it |
| `"` | drop it |
| `\|` | `-` |
| `<` `>` | drop them |

Do not use Unicode lookalikes to smuggle a colon back in.

## Provider identifiers

Add IDs on the **movie or series folder** (and, for movies, on the video basename so it still matches the folder).

```text
Name (year) [tmdbid-569094]
Name (year) [imdbid-tt9362722]
Name (year) [tvdbid-266189]
Name (year) [tmdbid-680] [imdbid-tt1234]
```

| Provider | Tag | Where the id comes from |
| --- | --- | --- |
| TMDB | `[tmdbid-123]` | URL `/movie/123-slug` or `/tv/123-slug` |
| IMDB / OMDb | `[imdbid-tt1234567]` | URL `/title/tt1234567/` |
| TVDB | `[tvdbid-123]` | Series id on the TVDB page (shows only) |

Do not invent IDs. Multiple IDs are valid. Year is optional but recommended.

## External subtitles and audio

Sidecar name = media basename + optional title/flags + language + extension.

```text
Film.mkv
Film.default.srt
Film.default.en.forced.ass
Film.forced.en.dts
Film.en.sdh.srt
Film.English Commentary.en.mp3

Series Name A (2021) S01E01 Title.avi
Series Name A (2021) S01E01 Title.ja.ass
Series Name A (2021) S01E01 Title.commentary.ja.aac
```

Flags (dot-separated, several allowed):

| Meaning | Flag |
| --- | --- |
| Default | `default` |
| Forced | `forced`, `foreign` |
| Hearing impaired | `sdh`, `cc`, `hi` |

`hi` alone is Hindi. `title.en.hi.srt` is English + hearing-impaired.

Unparsed text becomes the stream title (`English Commentary` above). Flags are ignored on containers that already have more than one stream.

`VIDEO_TS` / `BDMV` folders do **not** support external subtitle or audio tracks.

## Multiple parts (stacking)

Split content that should play as one item:

```text
Movie Name-cd1.mkv
Movie Name-cd2.mkv
Series Name A (2025) S01E01-part-1.mkv
Series Name A (2025) S01E01-part-2.mkv
```

Part types: `cd`, `dvd`, `part`, `pt`, `disc`, `disk`.

Separator before the part token, and optionally between type and number: space, `.`, `-`, `_`. Number is digits or `a`–`d`.

**Does not work with multiple versions or manual merge.** Pick one scheme.

`S02E03 Part 1.mkv` (space + words in the episode title) is **not** stacking. Stacking needs `-part-1` / `-cd1` etc.

## 3D

Require both `3D` and a format flag, case-insensitive, bounded by space / `-` / `.` / `_`:

| Format | Flag |
| --- | --- |
| Half side-by-side | `hsbs` |
| Full side-by-side | `fsbs` |
| Half top-and-bottom | `htab` |
| Full top-and-bottom | `ftab` |
| MVC | `mvc` |
| Anaglyph | not supported |

```text
Awesome 3D Movie (2022).3D.FTAB.mp4
Series Name A (2022) S01E01 Some Episode.3d.hsbs.mp4
Awesome 3D Movie (2022) - 3D_FTAB.mp4    # version grouping, movies only
```

## Extras

Preferred: a dedicated subfolder next to the movie / series / season:

`behind the scenes`, `deleted scenes`, `interviews`, `scenes`, `samples`, `shorts`, `featurettes`, `clips`, `other`, `extras`, `trailers`, `theme-music`, `backdrops`

Single-file shortcuts in the same folder: `trailer.ext`, `sample.ext`.

Suffixes (most have **no** space): `-trailer`, `.trailer`, `_trailer`, ` trailer`, same set for `sample`; plus `-scene`, `-clip`, `-interview`, `-behindthescenes`, `-deleted`, `-deletedscene`, `-featurette`, `-short`, `-other`, `-extra`.

Theme songs: `theme.ext` or `theme-music/*`. Theme videos: `backdrops/*`.

## Images

External images in the media folder win over providers / embedded art.

| File | Type | Movies | Series | Season | Episode | Album | Artist |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `poster` `folder` `cover` `default` | Primary | yes | yes | yes | | yes | `folder` only for artist |
| `movie` | Primary | yes | | | | | |
| `show` | Primary | | yes | | | | |
| `jacket` | Primary | | | | | yes | |
| `Name-thumb.jpg` | Primary | | | | yes | | |
| `backdrop` `fanart` `background` `art` | Backdrop | yes | yes | yes | | yes | |
| `banner` | Banner | yes | yes | yes | | yes | |
| `logo` `clearlogo` | Logo | yes | yes | yes | | yes | |
| `landscape` `thumb` | Thumb | yes | yes | yes | | yes | |

Multiple backdrops: `backdrop-1.jpg`, `backdrop2.jpg`. Names work standalone (`logo.png`) or as a suffix (`movie-logo.png`).

Prefer `cover.jpg` for movies/albums and `folder.jpg` for artist folders.

## Containers

Common video: `mkv`, `mp4`. Disc folders: `VIDEO_TS`, `BDMV` (no versions, parts, or external tracks). `.iso` is unsupported - remux to `mkv` or extract only if asked.

Music container exceptions are in [music.md](music.md#containers).
