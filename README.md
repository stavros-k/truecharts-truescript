# TrueScript

This script can help with:

- Updating Truenas SCALE applications
- Backup / Restore `ix-applications` dataset
- Mount / Unmount `PVC` storage
- Prune Container Images.

## Usage:

| Flag                | Parameters  | Description                                                                                                                                       |
| ------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `-m`                | None        | Initiates mounting feature, choose between unmounting and mounting PVC storage                                                                       |
| `-r`                | None        | Opens a menu to select a TrueScript backup to restore that was taken on your `ix-applications` dataset                                            |
| `-b <# of backups>` | Int \| None | Back-up your `ix-applications dataset`. You have specify a max number of backups to keep after -b                                                 |
| `-i <appname>`      | String      | Add an application to ignore list.                                                                                                                |
| `-t <seconds>`      | Int         | Set a custom timeout in seconds. This applies to `-u`, `-U` (Timeout from `Deploying` to `Active`) and `-m` (Timeout from `Active` to `Stoppped`) |
| `-s`                | None        | Sync Catalog                                                                                                                                      |
| `-u`                | None        | Apply all application updates, **excluding** major verions                                                                                           |
| `-U`                | None        | Apply all application updates, **including** major verions                                                                                        |
| `-p`                | None        | Prune unused container images                                                                                                                        |

## Examples

**Example for automatic updates with a `cron job`**
```
bash /mnt/POOLNAME/PATH/TO/SCRIPT/truescript.sh -b 14 -i portainer -i nextcloud -t 600 -sup
```

*Explantion*:
- `-b 14` Will keep up to 14 snapshots of your ix-applications dataset. Deleting oldest backups that exceed the `14` target.
- `-i portainer` Will ignore updates for the app named `portainer`.
- `-i nextcloud` Will ignore updates for the app named `nextcloud`.
- `-t 600` Will wait for `600` seconds, until an app goes from `Deploying` to `Active` when updating. (or until an app goes from `Active` to `Stopped` when mounting PVC Storage).
- `-s` Will sync the catalogs before checking for updates.
- `-u` Update only apps that do NOT have **major** updates.
- `-p` Prune container images.

**Example for mounting `PVC` Storage**

```
bash /mnt/POOLNAME/PATH/TO/SCRIPT/truescript.sh -t 600 -m
```

**Example for resttoring `ix-applications` dataset**
```
bash /mnt/POOLNAME/PATH/TO/SCRIPT/truescript.sh -r
```
