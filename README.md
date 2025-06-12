Teleport Redo
=============

Chat commands for requesting teleport to another player or for another player to come to you.

Includes a "Do-not-disturb" command to manage receiving requests from individuals or everyone.

Also includes a "Teleport Public Places" command.

___

## Commands

### Player to Player

- Request teleporting to player:

  `/tpr <playername>`

- Request another player to teleport to you:

  `/tphr <playername>`

- Accept  teleport request:

  `/tpy`

- Deny teleport request:

  `/tpn`

### Do Not Disturb

- Toggle receiving teleport requests from everyone

  `/tpdnd`
  
- Toggle receiving teleport requests from an individuals

  `/tpdnd player_name`

- Show your 'Do not disturb' list:

  `/tpdnd !show`

- Clear your 'Do not disturb' list:

  `/tpdnd !clear`

### Teleport Public Place

- Show the list of available Public Teleport locations:

  `/tpp` 

- Travel to one of the listed `tpp` locations:

  `/tpp place_name`

- Reload places from file:

  `/tpp_reload`

**Adding new `tpp` positions must be added to the `tpp_places.lua` file, then reloaded via command.**

The keys become the command parameter. For example, to add a new area called "mine-10k" add the key and position to `tpp_places.lua`:

```lua
return {
  template = {x = 0, y = 0, z = 0},
  -- because of the dash (-) symbol we enclose the key
  ["mine-10k"] = {x = 0, y = -10000, z = 0},
}
```

Once that's done, use the in-game command `/tpp_reload` to apply the changes made.

The management of tpp places may change in a future release.

___

MIT (c) 2024-2025 monk, Discord ID:699370563235479624

Current Version **`0.0.3`**
