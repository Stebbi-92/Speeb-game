# Playing Together

Up to eight players in the Ashen Waste, or four in the trials. One hosts; the others join. Choose **Walk Together** on the title screen.

## Hosting

Give your game a name and choose **who can find it**:

- **Everyone**: shown in the server list on the internet. Anyone can join, or use the code.
- **My network**: shown to players on your own network. Friends elsewhere join with the code.
- **Only with the code**: not shown anywhere.

You can also set a word that joiners must give. Once hosting, the gathering place shows a six-letter **join code** to give to friends.

## Joining

Type the join code (or an address and port) and press **Join**, or pick a game from the **Fellowships** list. Each one shows where it walks, how full it is, its day and how many fires are lit, and whether it is closed. Search it, hide full or closed games, and sort by players, name or nearness. A closed game wants its word in the field above before you join.

## Getting through any router

Joining from the internet list or by code works whatever the host's router is, with no port to open, even on mobile networks. Brelm connects the two of you straight when it can, and by a relay when nothing else gets through. Joining by a typed address still needs the host's port open (HOSTING.txt says how). This came in 0.25, which is a full download.

## In the game

- Press **L** to show the fellowship: each player's health and how far away they are. Otherwise only a fallen friend is shown, so the screen stays clear.
- Joins and leaves are shown under the compass.
- Marks you put on the map are shared, and show on everyone's compass.
- Hold the interact key on a fallen friend to raise them.
- Hand things to a friend nearby from your pack.
- Beds can belong to one player. Lie down in a bed to make it yours, give it to a friend or free it. Only its owner wakes there after a fall.
- With more than four, three in four lying down is enough to sleep through the night.
- The Longboat seats eight.
- The host can open **Players** in the pause menu and **Send away** someone. They can't come back under that name until the host closes the game.

## Walking together

- **Squads.** Players who keep within about 40 m of each other for half a minute fall into a squad of two to four. When one of you slays a foe, the others of your squad within 150 m learn half as much from it. Stray far from your squad for three minutes and you leave it. Squadmates are marked "squad" in the fellowship list.
- **Your own share.** Loot from a great one and from road events falls as a satchel for each player. You see only your own.
- **Coming in late.** A new player in a fellowship that has lit beacons comes with what it can spare: worked-up starting arms, a revolver, more ammunition and healing, and more again for each beacon lit.
- **Trades.** If you lack what only a friend's trade makes, What now tells you whom to ask.
- **Vault gates.** The last gate in a deep vault, before its keeper, is wound up at two winches, one each side. Alone it takes about twenty seconds; two together, four.
- **Boat stations.** Each seat on a boat is a station. The **helm** steers. The **sail**-hand raises and lowers the sail and runs the boat a quarter faster. The **lookout** sees forms on the water far off and calls where they lie. The **gun** seat holds a swivel: shots from it strike a third harder. Each **oar** manned on the Longboat, or the raft's second paddle, rows faster. Hold interact on the boat to move to a free station.
- **Two fronts.** With five or more players, kindling a beacon also brings a raid on the nearest camp to it, so some must ride back to hold it while the others keep the vigil.

## A bigger fellowship, a harder waste

The more who walk together, the more the waste sends: more forms at night, at ruins, on the roads and in the vaults, each a little harder to bring down, and the great ones much harder. The first four count in full; past four, each counts for half. At nightfall the game says how much harder the night will be.

The world belongs to the host and is saved on the host's computer. Each player's own character (pack, skills, map) is kept on their own computer, for that world.

## A dedicated server

A server with no player of its own. On Windows, run **Brelm Server.bat**; on a Mac or Linux, **Brelm Server.command** or **Brelm Server.sh** (these run in a terminal). HOSTING.txt has the details, and how to open the port.

The server keeps one world of the Ashen Waste always ready: it loads the world as it starts, and you walk straight into it when you join. While no one is there, the world is paused, so no time passes and nothing happens until someone comes back. It is saved every few minutes, when the last player leaves, and when the server is stopped. Each player's own character is kept on their own computer, as with any host.

On Windows the server opens a window to run it from:

- **Along the top**: the name, whether the world is running or paused (and why), players, world, time up, last save, whether it is on the internet list, the port and the addresses to join at.
- **Players**: who is here and their ping. **Kick** or **Ban** them, or send a message to everyone.
- **World**: **Save now**, **Restart world**, load a saved world or make a new one (with a seed if you like). Choose when the world runs: pause when no one is here, always run, or stay paused.
- **Settings**: name, password, most players, difficulty, internet list, how often to save, pause when empty, port. **Apply** puts them in place and saves them. A new port needs a restart.
- **Updates**: check for a new version, read its notes, download it and restart onto it. The world is saved first. It can check by itself when it starts, and update by itself when no one is connected.
- **Log**: everything the server has said, with **Copy log** and **Open log folder**.
- **Stop server** asks first, then saves the world and stops. Closing the window does the same.

Without a window, type commands into the terminal: `status`, `list`, `save`, `say <text>`, `kick <name|id>`, `ban <name|id>`, `pause`, `resume`, `auto`, `worlds`, `load <world>`, `new <world> [seed]`, `update`, `restart`, `quit`, `help`.

The settings are kept in **server.cfg** in Brelm's data folder. It is made on the first start and can be edited by hand while the server is stopped. It also remembers the world in use and when it runs. Options on the command line override it for that run:

- `world=NAME` picks which world it keeps, and `seed=` the seed of a new one (a number or a word).
- `autosave=MINUTES` sets how often it saves while it runs. `always_run` keeps it running with no one there.
- `port=`, `name=`, `password=`, `max_players=`, `difficulty=`, `public` and `lobby=` as in HOSTING.txt.
- `config=<path>` uses another settings file.
- `persist=0` gives the old kind of server: the first to join chooses a trial.

Banned players are listed in **server_bans.json** in the same folder, and it can be edited while the server runs.
