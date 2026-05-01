# BabiGuide — Backend API Specification

This document lists every backend endpoint required by the BabiGuide Flutter app, derived from the current data models, screens, and user flows. The mobile app is a guide for restaurants/hotels/businesses in Abidjan, Côte d'Ivoire, with browsing, search, reviews, photos, maps, and personalization.

## Conventions

- **Base URL:** `https://api.babiguide.app/v1` (TBD)
- **Format:** JSON for all request and response bodies, except media uploads which use `multipart/form-data`.
- **Auth:** Bearer token in `Authorization: Bearer <jwt>` header. Most read endpoints support guest access; all write endpoints require auth.
- **Localization:** Send `Accept-Language: fr` or `en` (default `fr`). Responses with localizable text fields return strings in the requested language.
- **Pagination:** Cursor-based when possible (`?cursor=<opaque>&limit=20`), fall back to `?offset=&limit=` for simple lists.
- **Timestamps:** ISO 8601 in UTC (`2026-04-30T14:32:00Z`).
- **Currency:** Prices returned as strings (e.g. `"8 500 F"`, `"₣₣"`) to keep formatting on the server.
- **Errors:** `{ "error": { "code": "string", "message": "string", "details": {...} } }` with appropriate HTTP status.

---

## 1. Data Models

### 1.1 `Place` (list/card view)
Used in home feed, search results, and saved lists. Source: [lib/data.dart:3-31](lib/data.dart#L3-L31).

```json
{
  "id": "norima",
  "name": "Chez Norima",
  "cuisine": "Cuisine ivoirienne · Attiéké",
  "neighborhood": "Cocody · Angré",
  "rating": 4.8,
  "reviews": 312,
  "price": "₣₣",
  "km": 1.2,
  "open": true,
  "seed": "norima",
  "tag": "Coup de cœur",
  "photo_label": "POULET BRAISÉ",
  "photo_url": "https://cdn.babiguide.app/places/norima/cover.jpg"
}
```

| Field | Type | Notes |
|---|---|---|
| `id` | string | Stable slug or UUID |
| `name` | string | |
| `cuisine` | string | Display string, dot-separated subtypes |
| `neighborhood` | string | Display string, e.g. `"Cocody · Angré"` |
| `rating` | number (float) | 0.0 – 5.0 |
| `reviews` | integer | Total review count |
| `price` | string | One of `₣`, `₣₣`, `₣₣₣`, `₣₣₣₣` |
| `km` | number (float) | Distance from caller; requires `lat`/`lng` query, otherwise null |
| `open` | boolean | Currently open at request time, server-computed from hours |
| `seed` | string | Stable identifier used by the client to render image placeholders |
| `tag` | string\|null | Editorial badge: `"Coup de cœur"`, `"Tendance"`, `"Local"`, etc. Localized. |
| `photo_label` | string | Short uppercase caption for the cover photo |
| `photo_url` | string | Cover image URL (the app currently uses placeholders; backend must return a real URL) |

### 1.2 `Neighborhood`
Source: [lib/data.dart:33-39](lib/data.dart#L33-L39).

```json
{ "id": "cocody", "name": "Cocody", "count": 142, "seed": "cocody", "photo_url": "..." }
```

### 1.3 `DetailPlace` (place detail screen)
Source: [lib/data.dart:289-322](lib/data.dart#L289-L322). Extended below to include the address/hours/phone fields the detail screen presents.

```json
{
  "id": "norima",
  "name": "Chez Norima",
  "cuisine": "Cuisine ivoirienne · Maquis chic",
  "neighborhood": "Cocody · Angré · 8e tranche",
  "rating": 4.8,
  "reviews": 312,
  "price": "₣₣",
  "verified": true,
  "photo_count": 28,
  "video_count": 6,
  "address": "Rue des Jardins, Cocody Angré 8e tranche, Abidjan",
  "phone": "+225 27 22 44 55 66",
  "hours": {
    "open_now": true,
    "today_until": "23:00",
    "weekly": [
      { "day": 1, "open": "11:30", "close": "23:00" },
      { "day": 2, "open": "11:30", "close": "23:00" }
    ]
  },
  "location": { "lat": 5.3667, "lng": -3.9667 },
  "amenities": ["wifi", "parking", "terrace", "clean_toilets", "ac", "card"],
  "is_favorited": false,
  "share_url": "https://babiguide.app/p/norima"
}
```

### 1.4 `SubRating` (rating breakdown)
Source: [lib/data.dart:128-146](lib/data.dart#L128-L146). The 9 categories are fixed.

```json
[
  { "id": "food",     "label": "Plats",     "icon": "fork",     "value": 4.9 },
  { "id": "menu",     "label": "Carte",     "icon": "money",    "value": 4.6 },
  { "id": "staff",    "label": "Service",   "icon": "staff",    "value": 4.8 },
  { "id": "toilet",   "label": "Toilettes", "icon": "toilet",   "value": 4.4 },
  { "id": "ambiance", "label": "Ambiance",  "icon": "ambiance", "value": 4.7 },
  { "id": "price",    "label": "Prix",      "icon": "money",    "value": 4.3 },
  { "id": "wait",     "label": "Attente",   "icon": "clock",    "value": 4.2 },
  { "id": "wifi",     "label": "Wifi",      "icon": "wifi",     "value": 4.0 },
  { "id": "park",     "label": "Parking",   "icon": "park",     "value": 4.5 }
]
```

`id` and `icon` keys are stable. `label` is localized.

### 1.5 `GalleryItem` (photo/video gallery)
Source: [lib/data.dart:148-169](lib/data.dart#L148-L169).

```json
{
  "id": "mg6",
  "url": "https://cdn.babiguide.app/places/norima/media/mg6.mp4",
  "thumb_url": "https://cdn.babiguide.app/places/norima/media/mg6-thumb.jpg",
  "seed": "mg6",
  "label": "STAFF CUISINE",
  "kind": "video",
  "duration": "0:38",
  "category": "staff",
  "author": { "id": "u_norima", "name": "Norima", "verified": true },
  "when": "1sem",
  "span": 2
}
```

| Field | Type | Notes |
|---|---|---|
| `kind` | enum | `"photo"` or `"video"` |
| `duration` | string\|null | Required when `kind = "video"`, format `m:ss` |
| `category` | enum | `"food"`, `"place"`, `"toilets"`, `"staff"` (server keys; client maps to localized labels) |
| `when` | string\|null | Relative time string for display, e.g. `"3j"`, `"1sem"`. Server may compute or return raw `created_at` and let client format. Prefer returning `created_at` ISO. |
| `span` | integer | 1 or 2 — editorial hint for grid sizing |
| `author.verified` | boolean | True for the venue's official account |

### 1.6 `MenuHighlight`
Source: [lib/data.dart:182-219](lib/data.dart#L182-L219).

```json
{
  "id": "m1",
  "name": "Poulet braisé entier",
  "description": "Mariné 24h, accompagné d'attiéké et alloco",
  "price": "8 500 F",
  "photo_url": "https://cdn.babiguide.app/places/norima/menu/m1.jpg",
  "seed": "m1",
  "label": "POULET BRAISÉ"
}
```

### 1.7 `ReviewItem`
Source: [lib/data.dart:221-261](lib/data.dart#L221-L261).

```json
{
  "id": "rv_123",
  "author": { "id": "u_42", "name": "Mariam K.", "avatar": "M", "avatar_url": null },
  "created_at": "2026-04-27T19:14:00Z",
  "when": "il y a 3 jours",
  "rating": 5,
  "text": "Le poulet braisé est juste parfait…",
  "sub": { "food": 5, "staff": 5, "toilet": 5 },
  "tags": ["Bon rapport qualité-prix", "Toilettes propres"],
  "media": [
    { "id": "rm1", "url": "...", "thumb_url": "...", "kind": "photo", "seed": "r1a" }
  ],
  "helpful_count": 12,
  "user_marked_helpful": false
}
```

`avatar` is a single character fallback; if `avatar_url` is null the client renders the initial.

### 1.8 `User`
```json
{
  "id": "u_42",
  "name": "Mariam K.",
  "avatar_url": null,
  "email": "mariam@example.com",
  "phone": "+225...",
  "preferences": {
    "cuisines": ["Cuisine ivoirienne", "Maquis & grillades", "Attiéké"],
    "lang": "fr",
    "dark_mode": false,
    "location_enabled": true
  },
  "created_at": "2026-01-12T10:00:00Z"
}
```

### 1.9 `MapMarker`
Source: [lib/screens/map_view.dart](lib/screens/map_view.dart).

```json
{
  "id": "norima",
  "name": "Chez Norima",
  "lat": 5.3667,
  "lng": -3.9667,
  "rating": 4.8,
  "price": "₣₣",
  "verified": true,
  "open": true,
  "sponsored": false
}
```

---

## 2. Authentication

### `POST /auth/signup`
Register a new user. Phone- or email-based; both supported.

**Request**
```json
{ "email": "mariam@example.com", "phone": null, "name": "Mariam K.", "password": "..." }
```

**Response 201**
```json
{ "token": "eyJ...", "user": { /* User */ } }
```

### `POST /auth/login`
**Request**
```json
{ "email": "mariam@example.com", "password": "..." }
```
or
```json
{ "phone": "+225...", "password": "..." }
```

**Response 200**
```json
{ "token": "eyJ...", "user": { /* User */ } }
```

### `POST /auth/logout`
**Response 204** — no body.

### `POST /auth/refresh`
Refresh JWT before expiry. Returns new `token`.

### `GET /me`
Returns the current `User`. Used by [lib/screens/splash.dart](lib/screens/splash.dart) and the profile tab to validate the stored session and hydrate user state.

---

## 3. Onboarding

The onboarding flow ([lib/screens/onboarding.dart](lib/screens/onboarding.dart)) has three steps:

1. **Welcome** — informational, no API call.
2. **Location** — request OS permission. After grant, post coordinates so the server can localize results.
3. **Tastes** — user picks cuisines from [lib/i18n.dart:60-88](lib/i18n.dart#L60-L88) (12 options).

### `POST /me/location`
**Request**
```json
{ "lat": 5.3599, "lng": -4.0083, "accuracy_m": 25 }
```
**Response 204**

### `PUT /me/preferences`
**Request**
```json
{ "cuisines": ["Cuisine ivoirienne", "Maquis & grillades", "Attiéké"] }
```
**Response 200** — updated `User`.

The fixed cuisine vocabulary (server-side keys) should be:
`ivoirienne`, `maquis`, `poisson`, `attieke`, `foutou`, `kedjenou`, `brunch_cafe`, `libanais`, `asiatique`, `italien`, `patisserie`, `vegan`. Localized labels live on the client (see i18n).

---

## 4. Home Feed

### `GET /home`
One-shot endpoint to populate [lib/screens/home.dart](lib/screens/home.dart) without 4 round trips.

**Query**: `lat`, `lng` (optional, for distance + "near me").

**Response 200**
```json
{
  "trending": [ /* Place[] */ ],
  "new_places": [ /* Place[] */ ],
  "neighborhoods": [ /* Neighborhood[] */ ],
  "greeting_hint": "evening"
}
```

`greeting_hint` lets the server tell the client whether to show "Bonsoir" / "Bonjour" based on local time in Abidjan.

If a single bundled endpoint is undesirable, expose them individually:

- `GET /places/trending?limit=10`
- `GET /places/new?limit=10`
- `GET /neighborhoods`

---

## 5. Places

### `GET /places`
List/search/filter places. Used by home, search ([lib/screens/search.dart](lib/screens/search.dart)), and saved.

**Query parameters**

| Param | Type | Notes |
|---|---|---|
| `q` | string | Free-text search (name, cuisine, neighborhood) |
| `lat`, `lng` | float | For distance + "near me" |
| `cursor` | string | Pagination cursor |
| `limit` | int | Default 20, max 50 |
| `sort` | enum | `relevance` \| `top_rated` \| `closest` \| `newest` (matches sortOptions in i18n) |
| `open_now` | bool | |
| `max_distance_km` | float | |
| `min_rating` | float | E.g. `4.0` for the "4★+" chip |
| `price` | csv | `₣,₣₣` or server keys `1,2,3,4` |
| `cuisines` | csv | One or more cuisine keys (see §3) |
| `amenities` | csv | Keys: `wifi`, `parking`, `terrace`, `clean_toilets`, `delivery`, `ac`, `card` |
| `neighborhood` | string | Neighborhood id |

**Response 200**
```json
{
  "items": [ /* Place[] */ ],
  "total": 142,
  "next_cursor": "opaque-string-or-null"
}
```

`total` powers the "142 résultats" label (see i18n).

### `GET /places/:id`
Returns `DetailPlace`.

### `GET /places/:id/sub_ratings`
Returns the 9-entry `SubRating[]`.

### `GET /places/:id/menu`
Returns `MenuHighlight[]`.

### `GET /places/:id/reviews`
**Query**: `cursor`, `limit`, `sort` (`recent` \| `helpful`).

**Response**
```json
{ "items": [ /* ReviewItem[] */ ], "total": 312, "next_cursor": null }
```

### `GET /places/:id/media`
**Query**:
- `category` — `all` (default) \| `food` \| `place` \| `toilets` \| `staff` \| `videos`
- `cursor`, `limit`

**Response**
```json
{
  "items": [ /* GalleryItem[] */ ],
  "counts_by_category": {
    "all": 34, "food": 18, "place": 7, "toilets": 3, "staff": 4, "videos": 6
  },
  "next_cursor": null
}
```

`counts_by_category` powers the tab counters in [lib/screens/media.dart](lib/screens/media.dart) and matches the keys in [lib/data.dart:284-287](lib/data.dart#L284-L287).

---

## 6. Reviews — Write Path

### `POST /places/:id/reviews`
Submit a review from [lib/screens/review.dart](lib/screens/review.dart).

**Request**
```json
{
  "rating": 5,
  "text": "Le poulet braisé…",
  "sub": {
    "food": 5, "menu": 4, "staff": 5, "toilet": 4, "ambiance": 5,
    "price": 4, "wait": 4, "wifi": 4, "park": 4
  },
  "tags": ["Bon rapport qualité-prix", "Toilettes propres"],
  "media_ids": ["m_abc", "m_def"]
}
```

`media_ids` are returned by `POST /media/upload` (see §9). Allows the client to upload photos before submitting.

**Response 201**
```json
{ "review": { /* ReviewItem */ } }
```

**Validation**
- `rating` ∈ [1, 5], required
- `sub` keys must be in the fixed set (food, menu, staff, toilet, ambiance, price, wait, wifi, park); each value ∈ [1, 5]
- `tags` matched against the canonical tag list ([lib/i18n.dart:215-237](lib/i18n.dart#L215-L237)); unknown tags rejected
- `text` length capped (suggest 2 000 chars)

### `POST /reviews/:id/helpful`
Toggle/mark helpful.

**Response**: `{ "helpful_count": 13, "user_marked_helpful": true }`

### `DELETE /reviews/:id/helpful`
Unmark.

### `DELETE /reviews/:id`
Author-only deletion of own review.

---

## 7. Favorites / Saved

Powering the heart icon on detail ([lib/screens/detail.dart](lib/screens/detail.dart)) and the "Sauvés" tab.

### `GET /me/favorites`
Returns paged `Place[]`.

### `POST /me/favorites`
**Request**: `{ "place_id": "norima" }` → 201 `{ "is_favorited": true }`

### `DELETE /me/favorites/:place_id`
204.

---

## 8. Search

### `GET /search/suggestions`
Autocomplete for the search bar.

**Query**: `q`, `lat`, `lng`

**Response**
```json
{
  "suggestions": [
    { "type": "place",        "id": "norima",  "label": "Chez Norima",     "sub": "Cocody" },
    { "type": "neighborhood", "id": "cocody",  "label": "Cocody",          "sub": "142 adresses" },
    { "type": "cuisine",      "id": "maquis",  "label": "Maquis",          "sub": "76 adresses" },
    { "type": "query",        "id": null,      "label": "maquis cocody",   "sub": null }
  ]
}
```

Place search itself goes through `GET /places?q=...`.

---

## 9. Media Upload

For review attachments and (later) venue-managed photos.

### `POST /media/upload`
`multipart/form-data`

| Part | Type | Notes |
|---|---|---|
| `file` | binary | Image (JPEG/PNG/HEIC) or video (MP4) |
| `kind` | string | `"photo"` or `"video"` |
| `category` | string | `food` \| `place` \| `toilets` \| `staff` (optional, can be inferred later) |
| `place_id` | string | Required — media is always attached to a place |
| `label` | string | Optional uppercase caption |

**Response 201**
```json
{
  "id": "m_abc",
  "url": "https://cdn.babiguide.app/...",
  "thumb_url": "https://cdn.babiguide.app/...-thumb.jpg",
  "kind": "photo",
  "duration": null,
  "seed": "m_abc"
}
```

**Constraints**
- Max 10 MB per photo, 50 MB per video
- Up to 4 attachments per review (matches the review uploader grid in [lib/screens/review.dart:255-282](lib/screens/review.dart#L255-L282))
- Server should run NSFW + face-presence checks; reject obvious abuse

---

## 10. Map

### `GET /map/markers`
**Query**: bounding box `sw_lat`, `sw_lng`, `ne_lat`, `ne_lng`, plus optional `cuisines`, `min_rating`, `open_now`, `q`.

**Response**
```json
{ "markers": [ /* MapMarker[] */ ], "truncated": false }
```

If the requested viewport contains too many markers, return a clustered subset and set `truncated: true`.

---

## 11. Sharing

### `POST /places/:id/share`
Logs the share and returns a canonical URL. The client uses this URL for OS share sheets.

**Response**
```json
{ "share_url": "https://babiguide.app/p/norima" }
```

The same URL is also returned inline on `GET /places/:id` as `share_url`, so the POST is only needed if you want analytics on intent.

---

## 12. Settings

### `PUT /me/settings`
**Request** (all optional)
```json
{
  "lang": "fr",
  "dark_mode": false,
  "location_enabled": true,
  "notifications_enabled": true
}
```

`lang` and `dark_mode` are also persisted client-side ([lib/app_state.dart](lib/app_state.dart)) — the server copy is for cross-device sync only.

---

## 13. Reference: Fixed Vocabularies

These are stable server-side keys the mobile client expects.

| Concept | Keys |
|---|---|
| Sub-rating categories | `food`, `menu`, `staff`, `toilet`, `ambiance`, `price`, `wait`, `wifi`, `park` |
| Media categories | `food`, `place`, `toilets`, `staff` (+ `videos` as a virtual filter) |
| Amenities | `wifi`, `parking`, `terrace`, `clean_toilets`, `delivery`, `ac`, `card` |
| Cuisines | `ivoirienne`, `maquis`, `poisson`, `attieke`, `foutou`, `kedjenou`, `brunch_cafe`, `libanais`, `asiatique`, `italien`, `patisserie`, `vegan` |
| Price tiers | `1` (`₣`), `2` (`₣₣`), `3` (`₣₣₣`), `4` (`₣₣₣₣`) |
| Sort | `relevance`, `top_rated`, `closest`, `newest` |
| Editorial tags | `coup_de_coeur`, `tendance`, `local`, `sponsored` |
| Languages | `fr`, `en` |

---

## 14. Endpoint Summary

| Method | Path | Purpose |
|---|---|---|
| POST | `/auth/signup` | Register |
| POST | `/auth/login` | Log in |
| POST | `/auth/logout` | Log out |
| POST | `/auth/refresh` | Refresh JWT |
| GET | `/me` | Current user |
| POST | `/me/location` | Save coordinates from onboarding step 2 |
| PUT | `/me/preferences` | Save cuisine prefs from onboarding step 3 |
| PUT | `/me/settings` | Sync language / theme / notif prefs |
| GET | `/home` | Bundled home feed |
| GET | `/places/trending` | Trending list |
| GET | `/places/new` | New venues |
| GET | `/neighborhoods` | Neighborhood tiles |
| GET | `/places` | List / search / filter |
| GET | `/places/:id` | Detail header |
| GET | `/places/:id/sub_ratings` | 9-category breakdown |
| GET | `/places/:id/menu` | Menu highlights |
| GET | `/places/:id/reviews` | Reviews list |
| GET | `/places/:id/media` | Photos/videos with category counts |
| POST | `/places/:id/reviews` | Submit review |
| DELETE | `/reviews/:id` | Delete own review |
| POST | `/reviews/:id/helpful` | Mark helpful |
| DELETE | `/reviews/:id/helpful` | Unmark helpful |
| GET | `/me/favorites` | Saved tab |
| POST | `/me/favorites` | Save place |
| DELETE | `/me/favorites/:place_id` | Unsave |
| GET | `/search/suggestions` | Autocomplete |
| POST | `/media/upload` | Upload photo/video |
| GET | `/map/markers` | Markers in viewport |
| POST | `/places/:id/share` | Log share, return canonical URL |
