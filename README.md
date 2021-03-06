# twash
Browse for top twitch streams using CLI!

Requires - jshon installed and bash > v4.0, xdg-utils is preffered on linux but can fall back to a regular browser like firefox.

I didn't like that the only solutions I could find for a CLI twitch browser to use with livestreamer were written in node. This is an attempt to bring a simple way to search for streams to launch with live streamer.

Usage:
All commands assume 5 results unless the second argument over rides this number

- twitch ts <#> | returns current top streams including streamer name, game name, and view count
- twitch tg <#> | returns current top games including game name, and view count
- twitch GAMENAME <#> | search for top streams for the given game name. Includes streamername, and view count
- twitch me | displays a list of live followed users, doesn't respect a limit. Includes live followed streamers and game names

Experimental Commands, Warning these are verbose

- twitch fol Username | attempts to follow a user
- twitch ufol Username | attempts to unfollow a user
- twitch com CommunityName | attempts to get a list of streamers in a community

Note - GAMENAME must be passed in quotes if it has spaces currently. On first run application will auth users via xdg-open or open for OSX. 

Example output:

```
$ twitch ts
Top Streams
NoahJ456 Call of Duty: Black Ops III 18755
C9Sneaky Overwatch 18688
reynad27 Pokémon Go 15326
Voyboy League of Legends 10822
AdmiralBulldog Dota 2 8930

$ twitch tg
Top Games
Call of Duty: Black Ops III 49760
League of Legends 49062
Overwatch 42979
Dota 2 33829
Hearthstone: Heroes of Warcraft 29971

$ twitch Overwatch
Top Streamers for Overwatch
C9Sneaky 18630
Surefour 5529
Zondalol 2444
Xargon0731 2386
Yapyap30 1304

$ twitch Overwatch 1
Top Streamers for Overwatch
C9Sneaky 18630

$ twitch me
Live Followed Streamers:
magic Magic: The Gathering
sxyhxy H1Z1: King of the Kill

$ twitch Pokemon
Top Streamers for Pokemon

...No matching games found, did you mean one of the following?
(Be sure to use quotes for games with spaces)
Pokémon Go 19004
Pokémon Omega Ruby/Alpha Sapphire 360
Pokémon Red/Blue 207
Pokémon FireRed/LeafGreen 13
Pokémon Black/White Version 2 12
```
