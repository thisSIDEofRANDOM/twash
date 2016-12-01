#!/bin/bash
#################################################
#Title: Twash
#Description: Twitch BASH CLI browser
#Author: tsunamibear
#Site: https://github.com/thisSIDEofRANDOM/twash
#Version: 1.6
#Release Date: 25/10/2016
#Release Notes: Seems that OAuth works again
# - Started working on function to generate
#   OAuth token/approval in browser
# - Initial follow/unfollow functions
# - Lots of junk to clean up in next release
#################################################

# Variables
LIMIT=5; COUNTER=0
OAUTH=""; TOKEN=""; USER="" #don't seem to need token passively anymore. Passing an oauth seems to be "good enough"
USAGE="twitch <ts,tg,me, {gamename}> <limit #>"
CONFIG="${HOME}/.config/twash"
ARRAY=mapfile

# Config file check/creation
if [ -f "${CONFIG}/config" ]; then
   . "${CONFIG}/config"
else
   echo "Config file missing, creating now..."
   mkdir -p ${CONFIG}

   read -p "OAUTH: " OAUTH

   echo "OAUTH=\"$OAUTH\"" >> "${CONFIG}/config"
   echo "LIMIT=$LIMIT" >> "${CONFIG}/config"

   echo "...config file created at ${CONFIG}/config"
   echo
fi

#The below opens a browser to authenticate and retrieve an OAUTH. We open up a nc to make the call back cleaner, but also messy.
#xdg-open 'https://api.twitch.tv/kraken/oauth2/authorize?response_type=token&client_id=5k0hscvhd7l4o7iy1j3bo8tmpmvspq4&redirect_uri=http://localhost:57483&scope=user_follows_edit'
#echo -e "HTTP/1.1 200 OK\n\n<script>alert('OAUTH Token: \\\n' + ((window.location.hash.substr(1)).split('&')[0]).split('=')[1])</script>You may close this window" | nc -l localhost 57483 > /dev/null

# Set array reader since some mac versions don't have mapfile
if ! command -v $ARRAY >/dev/null; then
   ARRAY=readarray
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
    echo "OAUTH not set, please modify script variable to continue."
    exit 1
fi

# Twitches now requires a token for some calls
# 2016-12-1 this doesn't seem to be the case anymore, a valid oauth is working again. Leaving this here as a oauth validator though
if ! TOKEN=$(curl -H "Authorization: OAuth $OAUTH" -s https://api.twitch.tv/kraken | jshon -Q -e token -e client_id -u); then
    echo "Incorrect OAUTH or Twitch API down" 
    exit 1
fi

# Hacky username set till I combine the above in to one call
USER=$(curl -H "Authorization: OAuth $OAUTH" -s https://api.twitch.tv/kraken | jshon -Q -e token -e user_name -u)

# Case Switch for functionality
case $1 in
   # Top Streams
   ts)
      echo "Top Streams"

      # Parse Twitch JSON using jshon
#      $ARRAY array < <(curl -H "Client-ID: $TOKEN" -s https://api.twitch.tv/kraken/streams?limit=$LIMIT | jshon -e streams -a -e channel -e name -u -p -e game -u -p -p -e viewers)
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
#      $ARRAY -t array < <(curl -H "Client-ID: $TOKEN" -s https://api.twitch.tv/kraken/games/top?limit=$LIMIT | jshon -e top -a -e game -e name -u -p -p -e viewers -u)
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
   # Else assume we are searching for a game
   # Follow a streamer
   fol)
      echo "Warning experimental function..."
      echo "Now Following $2"

      curl -H "Authorization: OAuth $OAUTH" -s -X PUT https://api.twitch.tv/kraken/users/$USER/follows/channels/$2 > /dev/null
   ;;
   # Unfollow a streamer
   ufol)
      echo "Warning experimental function..."
      echo "Unfollowing $2"

      curl -H "Authorization: OAuth $OAUTH" -s -X DELETE https://api.twitch.tv/kraken/users/$USER/follows/channels/$2
   ;;
   # Search for top streams of a game
   *)
      echo "Top streamers for $1"

      # Convert Spaces to %20 for webcall
      GAME=${1// /%20}

      # Parse Twitch JSON using jshon
#      $ARRAY -t array < <(curl -H "Client-ID: $TOKEN" -s https://api.twitch.tv/kraken/streams?limit=$LIMIT\&game=$GAME | jshon -e streams -a -e channel -e name -u -p -p -e viewers)
      $ARRAY -t array < <(curl -H "Authorization: OAuth $OAUTH" -s https://api.twitch.tv/kraken/streams?limit=$LIMIT\&game=$GAME | jshon -e streams -a -e channel -e name -u -p -p -e viewers)

      # Catch if game name was mis typed since has to be exact.
      if [ ${#array[@]} -eq 0 ]; then
         echo -e "\n...No matching games found, did you mean one of the following?\n(Be sure to use quotes for games with spaces)"

         # Use twitch API to suggest games based on the name made
         $ARRAY -t array < <(curl -H "Client-ID: $TOKEN" -s https://api.twitch.tv/kraken/search/games?q=$GAME\&type=suggest\&live=true |jshon -e games -a -e name -u -p -e popularity)

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
