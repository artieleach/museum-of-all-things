![museum of all things banner](./docs/moat_logo_large_colorful_over_screenshot.png)

- **[Project homepage](https://may.as/moat)**

- [Download releases from Github](https://github.com/m4ym4y/wikipedia-museum/releases/)

- [Download on itch](https://mayeclair.itch.io/museum-of-all-things)

The goal of this project is to make an interactive 3d museum that is generated
procedurally, using content from wikipedia to fill exhibits. The museum is
virtually limitless, allowing you to take doors from one exhibit to another,
depending on what is linked from that wikipedia article.

The text of the article is also inserted as informative plaques on the wall, so you
can read about the exhibit while looking at the pictures from it. Images are also
pulled from wikimedia commons in the category corresponding to the article.

Every exhibit is filled with hallways to other exhibits, based on the links in the
current exhibit's wikipedia page. You'll never run out of things to explore!

## Multiplayer

Explore the museum with friends! The Museum of All Things now supports online
multiplayer for up to 16 players.

### Features

- **Host or Join**: Start your own server or connect to a friend's game
- **Player Customization**: Set your name, choose a color, or use a custom skin from any Wikimedia image URL
- **Explore Together**: See other players in real-time as you walk through exhibits
- **Player Mounting**: Climb on top of other players and ride around the museum together
- **Room-Based Visibility**: Players are only visible when in the same exhibit, keeping things focused
- **Synchronized Transitions**: When the host enters a new exhibit, everyone follows along

### Hosting a Game

1. Select **Host** from the multiplayer menu
2. Set your port (default: 7777)
3. Enter your name and pick a color
4. Share your IP address with friends
5. Click **Start** when everyone has joined

### Joining a Game

1. Select **Join** from the multiplayer menu
2. Enter the host's address and port
3. Set your name and pick a color
4. Click **Join**

### Dedicated Server

For headless server hosting, launch with the `--server` command-line argument.
The server will manage all players without creating its own player character.

## Contributing

If you encounter bugs in the museum, file them on the [issues
page.](https://github.com/m4ym4y/museum-of-all-things/issues) **Please include
the platform you're running on, and the name of the exhibit that the bug
occurred in.** (screenshots are also helpful)

You may file feature requests, but keep in mind that I'm a solo developer
distributing a free project. I'll prioritize whatever I have time for and feel
motivated to work on.

~~I do not currently have any policy for allowing outside contributors to the
codebase. I might change that in the future, particularly if I pursue
localization in other languages.~~

[**Are you interested in adding your language to the Museum of All Things? Click Here!!**](docs/translation-guide.md)

There are now many contributors to this project! Feel free to submit any pull
request and I will review it. I am more likely to accept PRs that are bugfixes or
optimizations/visual upgrades. As for things that affect the creative direction
of the museum I am still a bit precious about controlling that roadmap myself so
no guarantees that those types of changes will be merged. If you are unsure, file
an issue and we can discuss it before you put too much work in.

### Currently supported languages (On main branch -- may not reflect latest release)

- English
- Portuguese
- French
- Spanish
- Japanese
- German
- Bengali
- Chinese

## Roadmap for Future Updates (Not in any order)

- Greater variety in theming and exhibit layouts
- Support for more media types, such as audio or 3d models
- ~~Support for more Wikipedia languages other than English~~ [Thank you so much to daviirodrig and all others who helped!](https://github.com/m4ym4y/museum-of-all-things/pull/59)
- ~~Multiplayer~~ Done!

## Credits

All exhibit content is sourced from Wikipedia and Wikimedia commons. This game is written in the [Godot engine](https://godotengine.org). Textures are from [AmbientCG](https://ambientcg.com/).

- Creator and Programmer: [Maya](https://github.com/m4ym4y)
- App Store Publishing and Multi-Platform Support: [David Snopek](https://www.snopekgames.com/)
- Audio: [Willow Wolf @ Neomoon](https://neomoon.one) (Accepting work on game audio)
- Dramaturgy: Emma Bee Pernudi-Moon
