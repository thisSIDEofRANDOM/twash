#!/bin/bash
#################################################
#Title: Twash
#Description: Twitch BASH CLI browser
#Author: tsunamibear
#Site: https://github.com/thisSIDEofRANDOM/twash
#Version: 2.0
#Release Date: 12/25/2019
#Release Notes: Twitch "New API"
# - fol,unfol,com broken on "New API"
# - Search no longer suggests games on "New API"
#################################################

# Variables
LIMIT=5; COUNTER=0
OAUTH=""; USER=""; COMID="" 
USAGE="twitch <ts,tg,me, {gamename}> <limit #>"
CONFIG="${HOME}/.config/twash"
ARRAY=mapfile
OPEN=xdg-open

# Reports some versions of mac don't have mapfile
if ! command -v $ARRAY >/dev/null; then
   ARRAY=readarray
fi

# Config file check/creation
if [ -f "${CONFIG}/config" ]; then
   . "${CONFIG}/config"
else
   # Native opener, might need to clean this up later
   if ! command -v $OPEN >/dev/null; then
      OPEN=open
      if ! command -v $OPEN >/dev/null; then
         echo "xdg-utils or OSX open commands missing, setting firefox as failback..."
         OPEN=firefox
      fi
   fi

   echo "Config file missing, creating file..."
   mkdir -p ${CONFIG}

   $OPEN 'https://id.twitch.tv/oauth2/authorize?response_type=token&client_id=5k0hscvhd7l4o7iy1j3bo8tmpmvspq4&&redirect_uri=https://thissideofrandom.github.io/twash/&scope=user:edit'
   # Incase we ever need to use a local redirect instead of github netcat is viable...
   #echo -e "HTTP/1.1 200 OK\n\n<script>alert('OAUTH Token: ' + ((window.location.hash.substr(1)).split('&')[0]).split('=')[1] + '\\\nRecord this in to your twash config')</script>You may now close this window." | nc -l localhost 57483 > /dev/null

   read -p "OAUTH: " OAUTH

   echo "OAUTH=\"$OAUTH\"" >> "${CONFIG}/config"
   echo "LIMIT=$LIMIT" >> "${CONFIG}/config"

   echo "...config file created at ${CONFIG}/config"
   echo
fi

# Usage Check
if [ $# -lt 1 ]; then
   echo "Usage: $USAGE"
   exit
fi

# Set Limit 
if [ $2 ]; then
   LIMIT=$2
fi

# OAUTH check
if [ -z $OAUTH ]; then
    echo "OAUTH not set, please fix or delete config to continue."
    exit 1
fi

# Validate OAUTH is OK before proceeding and grab our username here, Old use was for client_id which is static
if ! USER=$(curl -H "Authorization: OAuth $OAUTH" -s https://id.twitch.tv/oauth2/validate | jshon -Q -e user_id -u); then
    echo "Incorrect OAUTH or Twitch API down" 
    exit 1
fi

# Convert Game ID
convert_id() {
   curl -H "Authorization: Bearer $OAUTH" -s https://api.twitch.tv/helix/games/?id=$1 | jshon -e data -a -e name -u
}

# Case Switch for functionality
case $1 in
   # Top Streams
   ts)
      echo "Top Streams"

      # Parse Twitch JSON using jshon
      $ARRAY array < <(curl -H "Authorization: Bearer $OAUTH" -s https://api.twitch.tv/helix/streams?first=$LIMIT | jshon -e data -a -e user_name -u -p -e game_id -u -p -e viewer_count -u)

      # Convert game IDs to game Names
      # Note: This is slow, we should make a single call instead of $LIMIT calls
      # However calling multiple game_ids in the same call has no guarantee of order
      # Likely need to build a local cache/mapping in app
      for (( c=1; c<=${#array[@]}; c+=3 ))
      do
         array[$c]=`convert_id ${array[$c]}`
      done

      # Step Through Array 3 at a time
      while [ $COUNTER -lt $LIMIT ]; do
         echo ${array[@]:(($COUNTER*3)):3}
         ((COUNTER++))
      done
   ;;
   # Top Games
   tg)
      echo "Top Games"

      # Parse Twitch JSON using jshon
      $ARRAY -t array < <(curl -H "Authorization: Bearer $OAUTH" -s https://api.twitch.tv/helix/games/top?first=$LIMIT | jshon -e data -a -e name -u)

      # Step Through Array 2 at a time
      while [ $COUNTER -lt $LIMIT ]; do
         echo ${array[$COUNTER]}
         ((COUNTER++))
      done
   ;;
   # Live Followed
   me)
      echo "Live Followed Streamers:"

      # Pull follow IDs
      FOLLOW_IDS=$(curl -H "Authorization: Bearer $OAUTH" -s https://api.twitch.tv/hel"ix/users/follows?from_id=$USER&first=100" | jshon -e data -a -e to_id -u)

      FOLLOW_IDS=${FOLLOW_IDS//[[:space:]]/\&user_id=}

      # Pull follows based on OAUTH
      $ARRAY array < <(curl -H "Authorization: Bearer $OAUTH" -s "https://api.twitch.tv/helix/streams?first=$LIMIT&user_id=$FOLLOW_IDS" | jshon -e data -a -e user_name -u -p -e game_id -u -p -e viewer_count -u)

      # Set limit based on received value
      LIMIT=$((${#array[@]}/3))

      # Sad face if no follows are live
      if [ ${#array[@]} -eq 0 ]; then
         echo "No one you follow is live :("
      fi

      # Convert game IDs to game Names
      # Note: This is slow, we should make a single call instead of $LIMIT calls
      for (( c=1; c<=${#array[@]}; c+=3 ))
      do
         array[$c]=`convert_id ${array[$c]}`
      done

      # Step Through Array 3 at a time
      while [ $COUNTER -lt $LIMIT ]; do
         echo ${array[@]:(($COUNTER*3)):3}
         ((COUNTER++))
      done						  
   ;;
   # Follow a streamer
   fol)
      echo "The new Twitch API doesn't currently support following"
   ;;
   # Unfollow a streamer
   ufol)
      echo "The new Twitch API doesn't currently support unfollowing"
   ;;
   com)
      echo "The new Twitch API doesn't currently support communities"
   ;;
   # Search for top streams of a game
   *)
      echo "The new twitch API doesn't currently support fuzzy searching"
      echo "Top streams for $1"

      # Convert Spaces to %20 for webcall
      GAME=${1// /%20}
      
      # Convert Ampersands to %26 for webcall
      GAME=${GAME//&/%26}

      GAME_ID=$(curl -H "Authorization: Bearer $OAUTH" -s "https://api.twitch.tv/helix/games?limit=$LIMIT\&name=$GAME" | jshon -Q -e data -a -e id -u)

      # Sad face if no follows are live
      if [ $GAME_ID -eq 0 ]; then
         echo -e "\n...No matching games found, did you spell your game right?\n(Be sure to use quotes for games with spaces)"
      fi

      # Parse Twitch JSON using jshon
      $ARRAY array < <(curl -H "Authorization: Bearer $OAUTH" -s "https://api.twitch.tv/helix/streams?first=$LIMIT&game_id=$GAME_ID" | jshon -e data -a -e user_name -u -p -e viewer_count -u)

      # If returned streams is less than limit, adjust limit to avoid printing extra lines
      if [ ${#array[@]} -lt $(($LIMIT*2)) ]; then
         LIMIT=$((${#array[@]}/2))
      fi

      # Step Through Array 2 at a time
      while [ $COUNTER -lt $LIMIT ]; do
         echo ${array[@]:(($COUNTER*2)):2}
         ((COUNTER++))
      done
   ;;
esac
