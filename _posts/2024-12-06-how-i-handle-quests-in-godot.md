---
layout: post
author: Shomy
title: "How I handle quests in godot"
date: 2024-12-06
categories: posts
tags:
- Gamedev
- Godot
- Addon
---

For a long time, I've been maintaining a quest addon for Godot 4, [QuestSystem](https://github.com/shomykohai/quest-system), which I initially intended as a simple system for my projects.<br><br>
**But how do i use it?**

[![QuestSystem Banner](/media/posts/2024/quest_system_banner.png)](https://shomy.is-a.dev/quest-system)

## How to get started with QuestSystem

Before anything else, how do I install the addon in my projects?<br>

Thankfully, it's as easy as opening Godot and searching it on the asset store!

First step | Second step ⠀
:------:|:------:
![Godot Asset Lib (First step)](/media/posts/2024/godot_asset_lib_quest_system.png) | ![Quest System Download (Second step)](/media/posts/2024/godot_asset_lib_quest_system_download.png)

Then you're ready to start working with QuestSystem!

## How I design the quests' code

Being QuestSystem a generalized system, it may be hard for newcomers to understand how to work with it, and they may prefer more user-friendly addons, like [Questify](https://github.com/TheWalruzz/godot-questify) (which provides a Graph Node based approach).
<br><br>

> QuestSystem is intended to be easy, but <u>requires at least some coding knowledge.</u><br>

While I prefer a code-based approach, it's not scalable to some extent, and does not play well with Godot's **composition over inheritance** philosophy.<br>

That's why I designed my [quest script](https://github.com/shomykohai/advanced-quest-system-example/blob/main/quests/scripts/base_quest.gd) to be just one file that handles all quest resources.

### Breakdown of the BaseQuestResource class

Here's a breakdown of the symbols in the `BaseQuestResource` class

```gdscript
# base_quest_resource.gd
extends Quest
class_name BaseQuestResource

@export var steps: Array[QuestStep]

# Quest specific methods

func start(...):
    ...

func complete(...):
    ...

func get_quest_step(idx: int) -> QuestStep:
    ...

func complete_step(idx: int) -> Error:
    ...

func get_first_uncompleted_step() -> QuestStep:
    ...


# Serialize and deserialize

func serialize() -> Dictionary:
    ...

func deserialize(data: Dictionary) -> void:
    ...

```

As you might have noticed, there's a `QuestStep` class that has appeared.<br>
That's exactly how I handle quests in my project: **each** quest has a collection of **steps** that **need to be completed** before the quest itself can be considered complete.

Here's the code for [`QuestStep`](https://github.com/shomykohai/advanced-quest-system-example/blob/main/quests/scripts/quest_step.gd)


### Why make a QuestStep class?

QuestStep is a custom Resource that has to be extended to make more specific logic, and still allow for a composition approach.<br>

> Making this new resource allows us to define a generalized *step* that can be reused for many different quests, and edit its properties directly in Godot's Inspector.

Here's the example quest in the [advanced-quest-system-example](https://github.com/shomykohai/advanced-quest-system-example/) repo:


*The inspector* | *The quest step inspector* |
:------:|:------: 
![Quest System example inspector](/media/posts/2024/quest_system_example_inspector.png) | ![Quest Step inspector](/media/posts/2024/quest_system_example_inspector_step.png)


## The power of a modular quest system

QuestSystem not only allows you to create custom quests, but also **enables you to extend the manager (autoload) itself**.

This is incredibly useful for iterating (or adapt) the quest system across different projects with different needs without needing to modify the addon itself.

To achieve this, you can create a new script that extends `QuestSystemManagerAPI`, implement new methods (or override existing ones), and update the autoload path in the project settings.

![Quest System Settings](/media/posts/2024/quest_system_settings_autoload.png)


## Integrating with other addons

In my projects, I often integrate QuestSystem with [Pandora](https://github.com/bitbrain/pandora), a fantastic addon to define RPG data and more.<br>

Furthermore, QuestSystem has been used with many other plugins, such as [DialogueManager by Nathan Hoad](https://github.com/nathanhoad/godot_dialogue_manager), [Dialogic by Emilio](https://github.com/dialogic-godot/dialogic), and has been used as template for [Cogito's QuestSystem](https://github.com/Phazorknight/Cogito).

## Useful Resources & projects using the addon

**Projects & Resources**
- [QuestSystem documentation](https://shomy.is-a.dev/quest-system)
- [QuestSystem](https://github.com/shomykohai/quest-system)
- [Advanced Quest System Example](https://github.com/shomykohai/advanced-quest-system-example)
- [Cogito](https://github.com/Phazorknight/Cogito)

**Videos using QuestSystem**
- Trobugno: ["What's new? Quests and more | Arkaruh's Tale Devlog 2"](https://www.youtube.com/watch?v=xFB74hBJawA)
- LandonDevelops: ["Creating a quest system for my indie RPG game | Godot devlog"](https://www.youtube.com/watch?v=D6X2Ex6m0vk)

## Actually designing the quests

To design the actual content of the quests, I use [PuzzleDependencies](https://github.com/nathanhoad/godot_puzzle_dependencies) charts, which allow me to divide the quest flow into different logical steps.

Here's a simple chart representing the **"Help Nathan"** quest in the Advanced Quest System Example project:
![Help Nathan Chart](/media/posts/2024/help_nathan_quest_chart.png)

Doing this, it's easy to see how the steps should be implemented and ordered.

Then I hop into Godot's editor and make a new quest resource and fill in all necessary data (Quest name, description, etc).

I reuse the quest steps scripts (or make new ones if needed) and, again, fill the fields with the appropriate data (Name of the step, description, and specific data such as an Item to deliver or an NPC to interact with).

## Conclusions

This is just a small example of how I handle quests in my projects, but the addon is very flexible and can be used for many different purposes.<br>