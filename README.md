## Parcel

*Note: Parcel is a work in progress. This page explains its goals and planned features. Asterisks (\*) denote features not yet implemented.*

Parcel is a lightweight modpack management tool for Minecraft, designed for easy collaboration and rapid updates during the development of modpacks.


|![Parcel screenshot](/doc/ss1.png) | ![Parcel screenshot](/doc/ss2.png) | ![Parcel screenshot](/doc/ss3.png)|
|:-----:|:-----:|:-----:|

### Features

* **Simple, lightweight, easy to use**

Parcel has a simple and user-friendly interface, and less tech-savvy users should have no problems using it to download a pack.

* **Independent, portable, cross-platform**

Parcel isn't tied to any particular mod ecosystem, and supports downloading mods from CurseForge, Modrinth, Git repos\*, plain URLs\* and more. It uses a simple TOML modlist format, allowing modpack authors to distribute their pack as a single text file (see [this page regarding overrides](https://github.com/trashbyte/parcel/wiki/Overrides)). Built on Flutter, Parcel is cross-platform and runs on Windows, MacOS, and Linux.

* **Dead-simple configuration format**

Parcel uses a simple TOML file to define a pack. See this?

```toml
[[mod]]
name = "TCDCommons API"
filename = "TCDCommons API.jar"
server = "unsupported"
client = "optional"
source = { type = "modrinth", project = "Eldc1g37", version = "Jf38xzKF" }
note = "Required for Better Statistics Screen"
```

That's a mod entry. Just add one for each mod. You can easily add or update these by hand or using your own tools.

More information about the pack.toml format can be found [on the wiki](https://github.com/trashbyte/parcel/wiki/Pack.toml-format).

* **Designed for development**

Parcel is designed with pack development and collaboration in mind, and makes it clear what files need to be updated when a pack is updated, as well as the status of local files and the availability of updates. Keeping a pack in sync is as simple as syncing the pack.toml file (and [overrides](https://github.com/trashbyte/parcel/wiki/Overrides)).

### Roadmap

* **Pack editing features**

Parcel currently only reads modpack configs, not writes to them. If you don't mind editing the pack.toml by hand, it still works for distributing a pack to friends and letting them easily update it. Obviously, pack editing features are important and will be added soon.

* **Support fetching files from Git repositories**
* **Support fetching files from plain URLs**
* **Allow custom source of overrides to be defined (to make syncing easier)**
* **Support resourcepacks and shaderpacks**
* **And more!**
