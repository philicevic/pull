#!/bin/bash
echo 'pull'
echo '===='
echo ''

# Step 0: Handle parameter
while [ "$1" != "" ]; do
    parameter=`echo $1 | awk -F= '{print $1}'`
    value=`echo $1 | awk -F= '{print $2}'`
    case $parameter in
        --help)
          echo 'Help'
          echo '----'
          echo 'Possible parameter:'
          echo '  --environment'
          echo '  --software'
          echo '  --vvcode'
          echo '  --p-number'
          echo '  --remote-database-user'
          echo '  --remote-database-password'
          echo '  --remote-database-host'
          echo '  --remote-database-name'
          echo '  --local-database-user'
          echo '  --local-database-password'
          echo '  --local-database-host'
          echo '  --local-database-name'
          exit 1
          ;;
        --environment)
          environment=$value
          ;;
        --software)
          software=$value
          ;;
        --vvcode)
          vvcode=$value
          ;;
        --p-number)
          pNumber=$value
          ;;
        --remote-database-user)
          remoteDatabaseUser=$value
          ;;
        --remote-database-password)
          remoteDatabasePassword=$value
          ;;
        --remote-database-host)
          remoteDatabaseHost=$value
          ;;
        --remote-database-name)
          remoteDatabaseName=$value
          ;;
        --local-database-user)
          localDatabaseUser=$value
          ;;
        --local-database-password)
          localDatabasePassword=$value
          ;;
        --local-database-host)
          localDatabaseHost=$value
          ;;
        --local-database-name)
          localDatabaseName=$value
          ;;
        *)
          echo 'Error'
          echo '-----'
          echo 'Unknown parameter:'
          echo '  '$parameter
          exit 1
          ;;
    esac
    shift
done

# Step 1: Gather variables
echo '1/5 Gather variables'
echo '--------------------'
if [[ -z ${environment} ]];
then
  read -p 'Environment [docker|local]: ' environment
else
  echo 'Environment [docker|local]: '$environment
fi
if [[ -z ${software} ]];
then
  read -p 'Software [typo3|laravel]: ' software
else
  echo 'Software [typo3|laravel]: '$software
fi
if [[ -z ${vvcode} ]];
then
  read -p 'vvcode: ' vvcode
else
  echo 'vvcode: '$vvcode
fi
if [[ -z ${pNumber} ]];
then
  read -p 'P number: ' pNumber
else
  echo 'P number: '$pNumber
fi
if [[ -z ${remoteDatabaseUser} ]];
then
  read -p 'Remote database user: ' remoteDatabaseUser
else
  echo 'Remote database user: '$remoteDatabaseUser
fi
if [[ -z ${remoteDatabasePassword} ]];
then
  read -p 'Remote database password: ' remoteDatabasePassword
else
  echo 'Remote database password: '$remoteDatabasePassword
fi
if [[ -z ${remoteDatabaseHost} ]];
then
  read -p 'Remote database host: ' remoteDatabaseHost
else
  echo 'Remote database host: '$remoteDatabaseHost
fi
if [[ -z ${remoteDatabaseName} ]];
then
  read -p 'Remote database name: ' remoteDatabaseName
else
  echo 'Remote database name: '$remoteDatabaseName
fi
if [ $environment = 'local' ]; then
  if [[ -z ${localDatabaseUser} ]]; then
    read -p 'Local database user: ' localDatabaseUser
  fi
  if [[ -z ${localDatabasePassword} ]]; then
    read -p 'Local database password: ' localDatabasePassword
  fi
  if [[ -z ${localDatabaseHost} ]]; then
    read -p 'Local database host: ' localDatabaseHost
  fi
  if [[ -z ${localDatabaseName} ]]; then
    read -p 'Local database name: ' localDatabaseName
  fi
fi
if [ $environment = 'docker' ]; then
  dockerDatabaseUser=$vvcode
  echo 'Docker database user: '$dockerDatabaseUser
  dockerDatabasePassword=$vvcode
  echo 'Docker database password: '$dockerDatabasePassword
  dockerDatabaseHost=$vvcode'_database'
  echo 'Docker database host: '$dockerDatabaseHost
  dockerDatabaseName=$vvcode
  echo 'Docker database name: '$dockerDatabaseName
fi
databaseFilename='export-'$(date +%s)'.sql'
echo 'Database filename:' $databaseFilename
echo ''

# Step 2: Synchronize files
echo '2/5 Synchronize files'
echo '---------------------'
if [ $software = 'typo3' ]; then
  rsync -chavzP --delete --stats $pNumber@$pNumber.mittwald.info:/home/www/$pNumber/html/typo3/web/fileadmin/user_upload/ web/fileadmin/user_upload/
fi
if [ $software = 'laravel' ]; then
  rsync -chavzP --delete --stats $pNumber@$pNumber.mittwald.info:/home/www/$pNumber/html/laravel/storage/app/ storage/app/
fi
echo ''

# Step 3: Export database
echo '3/5 Export database'
echo '-------------------'
ssh $pNumber@$pNumber.mittwald.info << EOF
  cd html/
  mysqldump --ignore-table=$remoteDatabaseName.be_sessions --ignore-table=$remoteDatabaseName.cache_md5params --ignore-table=$remoteDatabaseName.cache_treelist --ignore-table=$remoteDatabaseName.cf_cache_hash --ignore-table=$remoteDatabaseName.cf_cache_hash_tags --ignore-table=$remoteDatabaseName.cf_cache_imagesizes --ignore-table=$remoteDatabaseName.cf_cache_imagesizes_tags --ignore-table=$remoteDatabaseName.cf_cache_pages --ignore-table=$remoteDatabaseName.cf_cache_pages_tags --ignore-table=$remoteDatabaseName.cf_cache_pagesection --ignore-table=$remoteDatabaseName.cf_cache_pagesection_tags --ignore-table=$remoteDatabaseName.cf_cache_rootline --ignore-table=$remoteDatabaseName.cf_cache_rootline_tags --ignore-table=$remoteDatabaseName.cf_extbase_datamapfactory_datamap --ignore-table=$remoteDatabaseName.cf_extbase_datamapfactory_datamap_tags --ignore-table=$remoteDatabaseName.cf_extbase_object --ignore-table=$remoteDatabaseName.cf_extbase_object_tags --ignore-table=$remoteDatabaseName.cf_extbase_reflection --ignore-table=$remoteDatabaseName.cf_extbase_reflection_tags --ignore-table=$remoteDatabaseName.tx_extensionmanager_domain_model_extension --ignore-table=$remoteDatabaseName.sys_log --ignore-table=$remoteDatabaseName.sys_domain --user="$remoteDatabaseUser" --password='$remoteDatabasePassword' --host="$remoteDatabaseHost" $remoteDatabaseName > $databaseFilename
EOF
scp $pNumber@$pNumber.mittwald.info:/home/www/$pNumber/html/$databaseFilename ./
echo ''

# Step 4: Import database
echo '4/5 Import database'
echo '-------------------'
if [ $environment = 'docker' ]; then
  docker cp $databaseFilename $dockerDatabaseHost:./$databaseFilename
  docker-compose exec -T database mysql --user="$dockerDatabaseUser" --password="$dockerDatabasePassword" $dockerDatabaseName < $databaseFilename
fi
if [ $environment = 'local' ]; then
  mysql --user="$localDatabaseUser" --password="$localDatabasePassword" --host="$localDatabaseHost" $localDatabaseName < $databaseFilename
fi
echo ''

# Step 5: Clean up
echo '5/5 Clean up'
echo '------------'
rm $databaseFilename
if [ $environment = 'docker' ]; then
  docker exec $dockerDatabaseHost rm ./$databaseFilename
fi
ssh $pNumber@$pNumber.mittwald.info << EOF
  rm /home/www/$pNumber/html/$databaseFilename
EOF
