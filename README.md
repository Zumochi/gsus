# GSUS - GitLab from Source Update Script

This script is purely intended for GitLab installations *from source with MySQL*. As such, it is only tested with that.

You _should_ not use it on any other setup (although it might work with Postgres with some minor modifications).

## Usage

The script will prompt you for the version you want to upgrade to.

You _should_ only upgrade from one major to the next; refrain from skipping some.
So from 8-14-stable don't go to 8-16-stable right away, but first to 8-15-stable, and _then_ 8-16-stable.

Before starting, please make sure there are no special steps required for the update in [the respective update docs](https://gitlab.com/gitlab-org/gitlab-ce/tree/master/doc/update).
If there are, apply them manually when the script is done (or, if the changes are too grave, don't use the script at all).

1. Turn off GitLab before using the script with e.g. `service gitlab stop` or `/etc/init.d/gitlab stop` (it should work on non-Debian-based distributions)
2. Login as the `git` user
3. Run the script `gitlab-update.sh`
4. If applicable, update your gitlab.yml and nginx configuration files, or the init script (the script will inform you about changes)
5. Start gitlab
6. ???
7. Profit

The script will automatically create a backup for you if something goes wrong.

It will also pause if something goes wrong in any of the steps, so you can easily bail out.

## License

This script is distributed under the MIT License, see LICENSE.md for the full license.

