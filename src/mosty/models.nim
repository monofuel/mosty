## Mattermost model type definitions and JSON hooks.

import
  std/[json, options, tables],
  jsony

type
  MattermostUser* = ref object
    id*: string
    username*: string
    email*: string
    nickname*: string
    first_name*: string
    last_name*: string
    roles*: string
    locale*: string
    create_at*: int64
    update_at*: int64
    delete_at*: int64

  MattermostBot* = ref object
    user_id*: string
    username*: string
    display_name*: string
    description*: string
    owner_id*: string
    create_at*: int64
    update_at*: int64
    delete_at*: int64

  MattermostChannel* = ref object
    id*: string
    team_id*: string
    channel_type*: string
    display_name*: string
    name*: string
    header*: string
    purpose*: string
    create_at*: int64
    update_at*: int64
    delete_at*: int64
    creator_id*: string

proc renameHook*(v: var MattermostChannel, fieldName: var string) =
  ## Rename the JSON field `type` to `channel_type` to avoid keyword collision.
  if fieldName == "type":
    fieldName = "channel_type"

proc dumpHook*(s: var string, v: MattermostChannel) =
  ## Serialize MattermostChannel, outputting `type` instead of `channel_type`.
  if v == nil:
    s.add "null"
    return
  s.add '{'
  s.dumpHook("id"); s.add ':'; s.dumpHook(v.id); s.add ','
  s.dumpHook("team_id"); s.add ':'; s.dumpHook(v.team_id); s.add ','
  s.dumpHook("type"); s.add ':'; s.dumpHook(v.channel_type); s.add ','
  s.dumpHook("display_name"); s.add ':'; s.dumpHook(v.display_name); s.add ','
  s.dumpHook("name"); s.add ':'; s.dumpHook(v.name); s.add ','
  s.dumpHook("header"); s.add ':'; s.dumpHook(v.header); s.add ','
  s.dumpHook("purpose"); s.add ':'; s.dumpHook(v.purpose); s.add ','
  s.dumpHook("create_at"); s.add ':'; s.dumpHook(v.create_at); s.add ','
  s.dumpHook("update_at"); s.add ':'; s.dumpHook(v.update_at); s.add ','
  s.dumpHook("delete_at"); s.add ':'; s.dumpHook(v.delete_at); s.add ','
  s.dumpHook("creator_id"); s.add ':'; s.dumpHook(v.creator_id)
  s.add '}'

type
  MattermostPost* = ref object
    id*: string
    channel_id*: string
    user_id*: string
    message*: string
    create_at*: int64
    update_at*: int64
    delete_at*: int64
    edit_at*: int64
    root_id*: string
    post_type*: string
    props*: Option[JsonNode]
    file_ids*: seq[string]
    metadata*: Option[JsonNode]

proc renameHook*(v: var MattermostPost, fieldName: var string) =
  ## Rename the JSON field `type` to `post_type` to avoid keyword collision.
  if fieldName == "type":
    fieldName = "post_type"

proc dumpHook*(s: var string, v: MattermostPost) =
  ## Serialize MattermostPost, outputting `type` instead of `post_type`.
  if v == nil:
    s.add "null"
    return
  s.add '{'
  s.dumpHook("id"); s.add ':'; s.dumpHook(v.id); s.add ','
  s.dumpHook("channel_id"); s.add ':'; s.dumpHook(v.channel_id); s.add ','
  s.dumpHook("user_id"); s.add ':'; s.dumpHook(v.user_id); s.add ','
  s.dumpHook("message"); s.add ':'; s.dumpHook(v.message); s.add ','
  s.dumpHook("create_at"); s.add ':'; s.dumpHook(v.create_at); s.add ','
  s.dumpHook("update_at"); s.add ':'; s.dumpHook(v.update_at); s.add ','
  s.dumpHook("delete_at"); s.add ':'; s.dumpHook(v.delete_at); s.add ','
  s.dumpHook("edit_at"); s.add ':'; s.dumpHook(v.edit_at); s.add ','
  s.dumpHook("root_id"); s.add ':'; s.dumpHook(v.root_id); s.add ','
  s.dumpHook("type"); s.add ':'; s.dumpHook(v.post_type); s.add ','
  s.dumpHook("props"); s.add ':'; s.dumpHook(v.props); s.add ','
  s.dumpHook("file_ids"); s.add ':'; s.dumpHook(v.file_ids); s.add ','
  s.dumpHook("metadata"); s.add ':'; s.dumpHook(v.metadata)
  s.add '}'

type
  MattermostPostList* = ref object
    order*: seq[string]
    posts*: Table[string, MattermostPost]

  MattermostReaction* = ref object
    user_id*: string
    post_id*: string
    emoji_name*: string
    create_at*: int64

  MattermostFileInfo* = ref object
    id*: string
    name*: string
    size*: int64
    mime_type*: string
    has_preview_image*: bool

  MattermostTeam* = ref object
    id*: string
    display_name*: string
    name*: string
    team_type*: string
    create_at*: int64
    update_at*: int64
    delete_at*: int64

proc renameHook*(v: var MattermostTeam, fieldName: var string) =
  ## Rename the JSON field `type` to `team_type` to avoid keyword collision.
  if fieldName == "type":
    fieldName = "team_type"

proc dumpHook*(s: var string, v: MattermostTeam) =
  ## Serialize MattermostTeam, outputting `type` instead of `team_type`.
  if v == nil:
    s.add "null"
    return
  s.add '{'
  s.dumpHook("id"); s.add ':'; s.dumpHook(v.id); s.add ','
  s.dumpHook("display_name"); s.add ':'; s.dumpHook(v.display_name); s.add ','
  s.dumpHook("name"); s.add ':'; s.dumpHook(v.name); s.add ','
  s.dumpHook("type"); s.add ':'; s.dumpHook(v.team_type); s.add ','
  s.dumpHook("create_at"); s.add ':'; s.dumpHook(v.create_at); s.add ','
  s.dumpHook("update_at"); s.add ':'; s.dumpHook(v.update_at); s.add ','
  s.dumpHook("delete_at"); s.add ':'; s.dumpHook(v.delete_at)
  s.add '}'
