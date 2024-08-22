# Retort - A Reaction Plugin for Discourse

[English](README.md) | [简体中文](README_zh.md)

Retort allows you and your users to add Slack-style reactions to Discourse posts.

![Retort](screenshots/retort.jpg)

## Installation

- Edit your web template and add the project clone url. (Refer to [how to install plugins](https://meta.discourse.org/t/install-plugins-on-a-self-hosted-site/19157))
- Rebuild your web container to install the plugin.

## Features

* More user-friendly front-end design
* More efficient database structure
* More customization options
* Support for administrators to remove specific emojis
* Support for displaying usage statistics in site analytics

## Site Customization Settings

Visit `/admin/site_settings/category/plugins?filter=plugin%3Aretort` to view all the site settings for the Retort plugin.

### Disabling Specific Emojis

You can disable specific emojis using the `retort disabled emojis` site setting.

### Limiting Emoji Undo Time

You can limit the time in seconds for users to undo their reactions through the `retort withdraw tolerance` site setting.

### Disabling the Plugin in Specific Categories

You can disable this plugin in specific categories through the `retort disabled categories` site setting. For the designated categories, users will not be able to view, add, or remove reactions.

### Limiting the Number of Reactions Per Post

The site setting `retort allow multiple reactions` determines whether users can react to the same post multiple times. If you want users to only have one reaction per post (e.g., if you are using Retort as a voting system), set this option to false.

## User Personalization Settings

Users can personalize settings through preferences. Personalization options include hiding reactions from ignored users and hiding all reactions.

## Issue Reporting and Contributions

If you encounter any issues while using the plugin or have suggestions for improvement, feel free to submit issues or pull requests on GitHub.

This plugin currently supports English and Simplified Chinese. If you think the translation needs improvement or want to contribute translations for other languages, please submit a pull request.

### License

This repository is a fork of [gdpelican/retort](https://github.com/gdpelican/retort), and the original plugin is released under the MIT license.

This plugin has been refactored and is maintained by @ShuiyuanSJTU, based on the original plugin, and is released under the MIT license. For more details, please refer to the LICENSE file.