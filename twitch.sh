#!/bin/bash
#################################################
#Title: Twash
#Description: Twitch BASH CLI browser
#Author: tsunamibear
#Site: https://github.com/thisSIDEofRANDOM/twash
#Version: 1.7
#Release Date: 05/12/2016
#Release Notes: Seems that OAuth works again
# - Auth opens browser window now for OAuth
# - Initial follow/unfollow functions
#################################################

# Variables
LIMIT=5; COUNTER=0
OAUTH=""; USER="" 
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

   $OPEN 'https://api.twitch.tv/kraken/oauth2/authorize?response_type=token&client_id=5k0hscvhd7l4o7iy1j3bo8tmpmvspq4&redirect_uri=https://thissideofrandom.github.io/twash/&scope=user_follows_edit'
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
if ! USER=$(curl -H "Authorization: OAuth $OAUTH" -s https://api.twitch.tv/kraken | jshon -Q -e token -e user_name -u); then
    echo "Incorrect OAUTH or Twitch API down" 
    exit 1
fi

# Case Switch for functionality
case $1 in
   # Top Streams
   ts)
      echo "Top Streams"

      # Parse Twitch JSON using jshon
      $ARRAY array < <(curl -H "Authorization: OAuth $OAUTH" -s https://api.twitch.tv/kraken/streams?limit=$LIMIT | jshon -e streams -a -e channel -e name -u -p -e game -u -p -p -e viewers)

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
      $ARRAY -t array < <(curl -H "Authorization: OAuth $OAUTH" -s https://api.twitch.tv/kraken/games/top?limit=$LIMIT | jshon -e top -a -e game -e name -u -p -p -e viewers -u)

      # Step Through Array 2 at a time
      while [ $COUNTER -lt $LIMIT ]; do
         echo ${array[@]:(($COUNTER*2)):2}
         ((COUNTER++))
      done
   ;;
   # Live Followed
   me)
      echo "Live Followed Streamers:"

      # Pull follows based on OAUTH
      $ARRAY -t array < <(curl -H "Authorization: OAuth $OAUTH" -s https://api.twitch.tv/kraken/streams/followed?stream_type=live | jshon -e streams -a -e channel -e name -u -p -e game -u)

      # Set limit based on received value
      LIMIT=$((${#array[@]}/2))

      # Sad face if no follows are live
      if [ ${#array[@]} -eq 0 ]; then
         echo "No one you follow is live :("
      fi

      # Step Through Array 2 at a time
      while [ $COUNTER -lt $LIMIT ]; do
         echo ${array[@]:(($COUNTER*2)):2}
         ((COUNTER++))
      done						  
   ;;
   # Follow a streamer
   fol)
      echo "Warning experimental function..."
      echo "Following $2"

      curl -H "Authorization: OAuth $OAUTH" -s -X PUT https://api.twitch.tv/kraken/users/$USER/follows/channels/$2 | jshon #> /dev/null
   ;;
   # Unfollow a streamer
   ufol)
      echo "Warning experimental function..."
      echo "Unfollowing $2"

      curl -H "Authorization: OAuth $OAUTH" -s -X DELETE https://api.twitch.tv/kraken/users/$USER/follows/channels/$2 | jshon -Q #> /dev/null
   ;;
   # Search for top streams of a game
   *)
      echo "Top streams for $1"

      # Convert Spaces to %20 for webcall
      GAME=${1// /%20}

      # Parse Twitch JSON using jshon
      $ARRAY -t array < <(curl -H "Authorization: OAuth $OAUTH" -s https://api.twitch.tv/kraken/streams?limit=$LIMIT\&game=$GAME | jshon -e streams -a -e channel -e name -u -p -p -e viewers)

      # Catch if game name was mis typed since has to be exact.
      if [ ${#array[@]} -eq 0 ]; then
         echo -e "\n...No matching games found, did you mean one of the following?\n(Be sure to use quotes for games with spaces)"

         # Use twitch API to suggest games based on the name made
         $ARRAY -t array < <(curl -H "Authorization: OAuth $OAUTH" -s https://api.twitch.tv/kraken/search/games?q=$GAME\&type=suggest\&live=true | jshon -e games -a -e name -u -p -e popularity)

         # Check again for results
         if [ ${#array[@]} -eq 0 ]; then
            echo "No live channels matching your game found"
            exit
         fi
      fi

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
