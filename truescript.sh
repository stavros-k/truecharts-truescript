#!/bin/bash

dir=$(pwd)
git remote set-url origin https://github.com/truecharts/truescript.git 2>&1 >/dev/null
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git fetch 2>&1 >/dev/null
git update-index -q --refresh 2>&1 >/dev/null
if [[ $(git status --branch --porcelain) ]]; then
  echo "script requires update"
  git reset --hard 2>&1 >/dev/null
  git checkout $BRANCH 2>&1 >/dev/null
  git pull 2>&1 >/dev/null
  echo "script updated"
  if [[ "$CHANGED" == "true" ]]; then
  echo "LOOP DETECTED, exiting"
  exit 1
  else
  echo "restarting script after update..."
  export CHANGED="true"
  . $dir/truescript.sh
  fi
else
  echo "script up-to-date"
  export CHANGED="false"
fi

#If no argument is passed, kill the script.
[[ -z "$*" ]] && echo "This script requires an arguent, use -h for help" && exit

number_of_backups=0
restore="false"
timeout=300
mount="false"
sync="false"
prune="false"
update_apps="false"
update_all_apps="false"
stop_before_update="false"

while getopts ":hsi:mrb:t:uUpS" opt
do
  case $opt in
    h)
      echo "These arguments can be ran in any order, see example below"
      echo "-m | Initiates mounting feature, choose between unmounting and mounting PVC data"
      echo "-r | Opens a menu to restore a TrueScript backup that was taken on you ix-applications pool"
      echo "-b | Back-up your ix-applications dataset, specify a number after -b"
      echo "-i | Add application to ignore list, one by one, see example below."
      echo "-t | Set a custom timeout in seconds when checking if either an App or Mountpoint correctly Started, Stopped or (un)Mounted. Defaults to 300 seconds"
      echo "-s | sync catalog"
      echo "-S | Stops App before update with -u or -U and restarts afterwards"
      echo "-U | Update all applications, ignores versions"
      echo "-u | Update all applications, does not update Major releases"
      echo "-p | Prune unused/old docker images"
      echo "-s | Stop App before attempting update"
      echo "EX | bash TrueScript.sh -b 14 -i portainer -i arch -i sonarr -i radarr -t 600 -sUp"
      echo "EX | bash /mnt/tank/scripts/TrueScript.sh -t 8812 -m"
      exit
      ;;
    \?)
      echo "Invalid Option -$OPTARG, type -h for help"
      exit
      ;;
    :)
      echo "Option: -$OPTARG requires an argument" >&2
      exit
      ;;
    b)
      re='^[0-9]+$'
      ! [[ $OPTARG =~ $re  ]] && echo -e "Error: -b needs to be assigned an interger\n$number_of_backups is not an interger" >&2 && exit
      number_of_backups=$OPTARG
      echo -e "\nNumber of backups was set to $number_of_backups"
      ;;
    r)
      restore="true"
      ;;
    i)
      ignore+=("$OPTARG")
      ;;
    t)
      re='^[0-9]+$'
      ! [[ $timeout =~ $re ]] && echo -e "Error: -t needs to be assigned an interger\n$timeout is not an interger" >&2 && exit
      timeout=$OPTARG
      ;;
    m)
      mount="true"
      ;;
    s)
      sync="true"
      ;;
    U)
      update_all_apps="true"
      ;;
    u)
      update_apps="true"
      ;;
    S)
      stop_before_update="true"
      ;;
    p)
      prune="true"
      ;;
  esac
done

backup(){
date=$(date '+%Y_%m_%d_%H_%M_%S')
cli -c 'app kubernetes backup_chart_releases backup_name=''"'TrueScript_"$date"'"'
mapfile -t list_backups < <(cli -c 'app kubernetes list_backups' | grep "HeavyScript_\|TrueScript_" | sort -Vr | awk -F '|'  '{print $2}'| tr -d " \t\r")
if [[  ${#list_backups[@]}  -gt  "number_of_backups" ]]; then
  overflow=$(expr ${#list_backups[@]} - $number_of_backups)
  echo && mapfile -t list_overflow < <(cli -c 'app kubernetes list_backups' | grep "HeavyScript_\|TrueScript_"  | sort -Vr | awk -F '|'  '{print $2}'| tr -d " \t\r" | tail -n "$overflow")
  for i in "${list_overflow[@]}"
  do
    cli -c 'app kubernetes delete_backup backup_name=''"'"$i"'"' &> /dev/null && echo -e "Deleting your oldest backup $i\nThis is to remain in the $number_of_backups backups range you set. " || echo "Failed to delete $i"
  done
fi
}
export -f backup

restore(){
list_backups=$(cli -c 'app kubernetes list_backups' | grep "TrueTool_\|HeavyScript_\|TrueScript_" | sort -rV | tr -d " \t\r"  | awk -F '|'  '{print NR-1, $2}' | column -t) && echo "$list_backups" && read -p "Please type a number: " selection && restore_point=$(echo "$list_backups" | grep ^"$selection" | awk '{print $2}') && echo -e "\nThis is NOT guranteed to work\nThis is ONLY supposed to be used as a LAST RESORT\nConsider rolling back your applications instead if possible.\n\nYou have chosen to restore $restore_point\nWould you like to continue?"  && echo -e "1  Yes\n2  No" && read -p "Please type a number: " yesno || { echo "FAILED"; exit; }
if [[ $yesno == "1" ]]; then
  echo -e "\nStarting Backup, this will take a LONG time." && cli -c 'app kubernetes restore_backup backup_name=''"'"$restore_point"'"' || echo "Restore FAILED"
elif [[ $yesno == "2" ]]; then
  echo "You've chosen NO, killing script. Good luck."
else
  echo "Invalid Selection"
fi
}
export -f restore


mount(){
echo -e "1  Mount\n2  Unmount All" && read -p "Please type a number: " selection

if [[ $selection == "1" ]]; then
  list=$(k3s kubectl get pvc -A | sort -u | awk '{print NR-1, "\t" $1 "\t" $2 "\t" $4}' | column -t | sed "s/^0/ /")
  echo "$list" && read -p "Please type a number : " selection
  app=$(echo -e "$list" | grep ^"$selection" | awk '{print $2}' | cut -c 4-)
  pvc=$(echo -e "$list" | grep ^"$selection" || echo -e "\nInvalid selection")
  status=$(cli -m csv -c 'app chart_release query name,status' | grep -E "(,|^)$app(,|$)" | awk -F ',' '{print $2}'| tr -d " \t\n\r")
  if [[ "$status" != "STOPPED" ]]; then
    [[ -z $timeout ]] && echo -e "\nSetting Default Timeout to 300\nChange timeout with -t" || echo -e "\nTimeout was set to $timeout"
    SECONDS=0 && echo -e "\nScaling down $app" && midclt call chart.release.scale "$app" '{"replica_count": 0}' &> /dev/null
  else
    echo -e "\n$app is already stopped"
  fi
  while [[ "$SECONDS" -le "$timeout" && "$status" != "STOPPED" ]]
    do
      status=$(cli -m csv -c 'app chart_release query name,status' | grep -E "(,|^)$app(,|$)" | awk -F ',' '{print $2}'| tr -d " \t\n\r")
      echo -e "Waiting $((timeout-SECONDS)) more seconds for $app to be STOPPED" && sleep 10
    done
  data_name=$(echo "$pvc" | awk '{print $3}')
  mount=$(echo "$pvc" | awk '{print $4}')
  volume_name=$(echo "$pvc" | awk '{print $4}')
  full_path=$(zfs list | grep $volume_name | awk '{print $1}')
  echo -e "\nMounting\n"$full_path"\nTo\n/mnt/temporary/$data_name" && zfs set mountpoint=/temporary/"$data_name" "$full_path" && echo -e "Mounted\n\nUnmount with the following command\nzfs set mountpoint=legacy "$full_path" && rmdir /mnt/temporary/"$data_name"\nOr use the Unmount All option\n"
  exit
elif [[ $selection == "2" ]]; then
  mapfile -t unmount_array < <(basename -a /mnt/temporary/* | sed "s/*//")
  [[ -z $unmount_array ]] && echo "Theres nothing to unmount" && exit
  for i in "${unmount_array[@]}"
    do
      main=$(k3s kubectl get pvc -A | grep "$i" | awk '{print $1, $2, $4}')
      app=$(echo "$main" | awk '{print $1}' | cut -c 4-)
      pvc=$(echo "$main" | awk '{print $3}')
      path=$(find /*/*/ix-applications/releases/"$app"/volumes/ -maxdepth 0 | cut -c 6-)
      zfs set mountpoint=legacy "$path""$pvc" && echo "$i unmounted" && rmdir /mnt/temporary/"$i" || echo "failed to unmount $i"
    done
else
  echo "Invalid selection, type -h for help"
  break
fi
}
export -f mount

sync(){
echo -e "\nSyncing all catalogs, please wait.." && cli -c 'app catalog sync_all' &> /dev/null && echo -e "Catalog sync complete"
}
export -f sync

prune(){
echo -e "\nPruning Docker Images" && docker image prune -af | grep Total || echo "Failed to Prune Docker Images"
}
export -f prune

update_apps(){
    mapfile -t array < <(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,container_images_update_available,status' | grep ",true" | sort)
    [[ -z $array ]] && echo -e "\nThere are no updates available" || echo -e "\n${#array[@]} update(s) available"
    [[ -z $timeout ]] && echo -e "\nSetting Default Timeout to 300\nChange timeout with -t" && timeout=300 || echo -e "\nTimeout was set to $timeout"
        for i in "${array[@]}"
            do
                n=$(echo "$i" | awk -F ',' '{print $1}') #print out first catagory, name.
                ottv=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #previous Truecharts version
                nttv=$(echo "$i" | awk -F ',' '{print $5}' | awk -F '_' '{print $1}' | awk -F '.' '{print $1}') #previous version) #New Truecharts Version
                oav=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') #previous version) #New App Version
                rollback_version=$(echo "$i" | awk -F ',' '{print $4}' | awk -F '_' '{print $2}')
                nav=$(echo "$i" | awk -F ',' '{print $5}' | awk -F '_' '{print $2}' | awk -F '.' '{print $1}') #previous version) #New App Version
                status=$(echo "$i" | awk -F ',' '{print $2}') #status of the app: STOPPED / DEPLOYING / ACTIVE
                tt=$(diff <(echo "$ottv") <(echo "$nttv")) #caluclating difference in major Truecharts versions
                av=$(diff <(echo "$oav") <(echo "$nav")) #caluclating difference in major app versions
                ov=$(echo "$i" | awk -F ',' '{print $4}') #Upgraded From
                nv=$(echo "$i" | awk -F ',' '{print $5}') #Upraded To
                [[ "${ignore[*]}"  ==  *"${n}"* ]] && echo -e "\n$n\nIgnored, skipping" && continue
                if [[ "$tt" == "$av" || "$update_all_apps" == "true" ]]; then #continue to update
                  startstatus=$status
                  if [[ $stop_before_update == "true" ]]; then 
                      echo -e "\n"$n"\nStopping prior to update..." && midclt call chart.release.scale "$n" '{"replica_count": 0}' &> /dev/null && SECONDS=0 || echo -e "FAILED"
                      while [[ "$status" !=  "STOPPED" ]]
                      do
                          status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep ""$n"," | awk -F ',' '{print $2}')
                          if [[ "$status"  ==  "STOPPED" ]]; then
                              echo "Successfully Stopped"
                              echo "Updating..." && cli -c 'app chart_release upgrade release_name=''"'"$n"'"' &> /dev/null && echo -e "Updated\n$ov\n$nv" || { echo "FAILED"; continue; }
                              continue
                          elif [[ "$SECONDS" -ge "$timeout" ]]; then
                              echo "Error: Run Time($SECONDS) has exceeded Timeout($timeout)"
                              break
                          elif [[ "$status" !=  "STOPPED" ]]; then
                              echo "Waiting $((timeout-SECONDS)) more seconds for $n to be STOPPED" && sleep 15
                              continue
                          fi
                      done
                  else
                      echo -e "\n$n\nUpdating" && cli -c 'app chart_release upgrade release_name=''"'"$n"'"' &> /dev/null && echo -e "Updated\n$ov\n$nv" && SECONDS=0 || { echo "FAILED"; continue; }
                  fi
                  test_and_revert $n $rollback_version $startstatus $
              else
                  echo -e "\n$n\nMajor Release, update manually"
                  continue
              fi
            done
}
export -f update_apps

test_and_revert(){
  ## $1 = App name
  ## $2 = Rollback version
  ## $3 = set to the status before update
  SECONDS=0
  failure="false"
  loopprevent="false"
  sleep 30
  while [[ "$status"  !=  "ACTIVE" ]]
  do
      status=$(cli -m csv -c 'app chart_release query name,update_available,human_version,human_latest_version,status' | grep ""$1"," | awk -F ',' '{print $2}')
      if [[ "$status"  ==  "STOPPED" ]]; then
          break
      elif [[ "$SECONDS" -ge "$timeout" && "$status"  ==  "DEPLOYING" ]]; then
          echo -e "Error: Run Time($SECONDS) for $1 has exceeded Timeout($timeout)\nIf this is a slow starting application, set a higher time with -t\nIf this applicaion is always DEPLOYING, you can disable all probes under the Healthcheck Probes Liveness section in the edit configuration\nReverting update..."
          failure="true"
          [[ "$failure"  ==  "true" ]] && midclt call chart.release.rollback "$1" "{\"item_version\": \"$2\"}" &> /dev/null
          if [[ "$loopprevent" == "true" ]]
            echo "Returing $1 to STOPPED state due to timeout after rollback.." && midclt call chart.release.scale "$n" '{"replica_count": 0}' &> /dev/null && echo "Stopped"|| echo -e "FAILED"
          elif [[ "$3"  ==  "STOPPED" ]]; then
            loopprevent="true"
            continue
          else
            break
          fi
      elif [[ "$status"  ==  "DEPLOYING" ]]; then
          sleep 15
          continue
      elif [[ "$status"  ==  "ACTIVE" && "$3"  ==  "STOPPED" ]]; then
          echo "Returing $1 to STOPPED state.." && midclt call chart.release.scale "$n" '{"replica_count": 0}' &> /dev/null && echo "Stopped"|| echo -e "FAILED"
          break
      fi
  done
}
export -f prune

if [ $restore == "true" ]; then
  restore
  exit
fi

if [[ $number_of_backups -gt 0 ]]; then
  backup
fi

if [ $mount == "true" ]; then
  mount
  exit
fi

if [ $sync == "true" ]; then
  sync
fi

if [ $update_all_apps == "true" ]; then
  update_apps
elif [ $update_apps == "true" ]; then
  update_apps
fi

if [ $prune == "true" ]; then
  prune
fi