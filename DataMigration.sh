#! /bin/bash

# author :- Shreyansh Nowlkha
# task :- to migrate Data from one server to another

currentPath=$(pwd)
scriptName=`basename $0`

check_DirExsists() {
    if [ ! -d "$1" ] 
    then
     echo "Error: Directory $1 does not exists."
     exit 1 
    fi
}

check_FileExistsInDir(){
 FileCheck=$( ls $1 | grep $2 )
 if [ ! -z "$FileCheck" ]
 then
      echo "Error: $2 script can't be present in $1 , Please move this script outside of the $1 and execute "
      exit 1
 fi   
}

check_Interger(){
   if ! [[ "$1" =~ ^[0-9]+$ ]]
   then
        echo "Sorry integers only"
        exit 1
   fi
}

check_SessionValidity(){
   if [ "$1" -eq "0" ]; then
    echo "Error: To Many sessions for $2 Backup Files"
    exit 1
   fi      
   
}

check_if_any_session_is_running(){

    local flag="false"
    cd $1/$2
     for session in $( ls -lh | egrep -v '^d' | awk '{print$9}' | awk '!/^$/' )
     do
        
        mycurrsession=$( screen -ls | grep $session )
        if [ ! -z "$mycurrsession" ]
        then
          flag="true"
          break
        fi
        

     done

      echo $flag
}

connection_status() {

  timeout 5 bash -c "</dev/tcp/$1/22" && echo "success" || echo "failed"
  

}

check_DirExsists_Target_Server(){

  
    if ssh -o StrictHostKeyChecking=no -l $1 $2 "[ -d $3 ]"
    then

          echo "$3 exsists on $2"
    else
          echo "Error: $3 doesn't present on $2" 
          exit 1
    fi

}




echo "Enter the absolute path of source(Backup) folder:"
read spath

echo "Enter the absolute path of target folder: "
read tpath

echo "Enter the Username of Target server: "
read username

echo "Enter the Ip addr/DNS name of Target server: "
read Ip

status=$(connection_status $Ip)

if [[ "$status" == "success" ]]
then
   echo "Connection to $Ip is success"
   sleep 5

elif [[ "$status" == "failed" ]]
then

 echo "Error: Connection to $Ip is Failed"
 exit 1

fi

check_DirExsists $spath

check_FileExistsInDir $spath $scriptName

check_DirExsists_Target_Server $username $Ip $tpath

cd $spath

let countBackupFiles=$( ls -alh | egrep -v '^d' | awk '{print$9}' | awk '!/^$/' | wc -l | xargs )

echo "************************* we have $countBackupFiles files inside $spath *************************"

let session_count
echo "Enter the no. of session you want:"
read session_count
check_Interger $session_count

ls -alh | egrep -v '^d' | awk '{print$9}' | awk '!/^$/'  > $currentPath/index.txt

let Files_In_Each_Session=$countBackupFiles/$session_count
check_SessionValidity $Files_In_Each_Session $countBackupFiles

migDir=""
while true
do
  echo "Enter the Directory Name you want to get created for your session File List :"
  read migDir
  if [ -d "$currentPath/$migDir" ]
  then
      myflag=$( check_if_any_session_is_running $currentPath $migDir )
      if [[ "$myflag" == "true" ]]
      then
       echo "Enter another Directory Name as it already Exists with running session"
       
      elif [[ "$myflag" == "false" ]]
      then
       rm -rf $currentPath/$migDir/*
       break
      fi
  else
    mkdir -p $currentPath/$migDir
    break    
  fi	
done


split -l $Files_In_Each_Session $currentPath/index.txt $currentPath/$migDir/"$migDir-file"

i=0
cd $currentPath/$migDir/
for file in $( ls -lh | awk '{print$9}' | awk '!/^$/' )
do
    
     screen -S $file -d -m bash -c "rsync -auvh --progress --recursive --files-from=$currentPath/$migDir/$file $spath $username@$Ip:$tpath --log-file=/tmp/$file.log"
     let i++
done

