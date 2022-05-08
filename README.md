# TrueScript

This script can help with:

- Updating Truenas SCALE applications
- Mount / Unmount PVC storage
- Prune Docker images.

## Usage:

| Flag | Parameters  | Description                                                                                                                                       |
| ---- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| -m   | None        | Initiates mounting feature, choose between unmounting and mounting PVC data                                                                       |
| -r   | None        | Opens a menu to select a TrueScript backup to restore that was taken on your `ix-applications` dataset                                            |
| -b   | Int \| None | Back-up your `ix-applications dataset`. You can also specify a max number of backups to keep after -b                                             |
| -i   | String      | Add an application to ignore list.                                                                                                                |
| -t   | Int         | Set a custom timeout in seconds. This applies to `-u`, `-U` (Timeout from `Deploying` to `Active`) and `-m` (Timeout from `Active` to `Stoppped`) |
| -s   | None        | Sync Catalog                                                                                                                                      |
| -u   | None        | Apply all application updates, **except** major verions                                                                                           |
| -U   | None        | Apply all application updates, **including** major verions                                                                                        |
| -p   | None        | Prune unused docker images                                                                                                                        |



### Examples

#### bash truescript.sh -b 14 -i portainer -i arch -i sonarr -i radarr -t 600 -sup

- This is your typical cron job implementation.
- -b is set to 14. Up to 14 snapshots of your ix-applications dataset will be saved
- -i is set to ignore portainer, arch, sonarr, and radarr. These applications will be ignored when it comes to updates.
- -t I set it to 600 seconds, this means the script will wait 600 seconds for the application to become ACTIVE before timing out and continuing to a different application.
- -s will just sync the repositories, ensuring you are downloading the latest updates
- -u update applications as long as the major version has absolutely no change, if it does have a change it will ask the user to update manually.
- -p Prune docker images.

- bash /mnt/tank/scripts/truescript.sh -t 8812 -m
- bash /mnt/tank/scripts/truescript/truescript.sh -r

### Example Cron Job

- `/mnt/speed/scripts/heavy_script/truescript.sh -b 14 -sup`
