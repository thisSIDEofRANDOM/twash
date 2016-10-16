#!/bin/bash
#################################################
#Title: Twash
#Description: Twitch BASH CLI browser
#Author: tsunamibear
#Site: https://github.com/thisSIDEofRANDOM/twash
#Version: 1.4
#Release Date: 16/10/2016
#TODO: Add better argument parsing/validation
#      Add interactive mode with livestreamer
#################################################

# Variables
LIMIT=5; COUNTER=0
USAGE="twitch <ts,tg, me, {gamename}> <limit #>"
# SAVE OAUTH HERE UNTIL CONFIG FILE SET UP
OAUTH=""
TOKEN=""
ARRAY=mapfile

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
if ! TOKEN=$(curl -H "Authorization: OAuth $OAUTH" -s https://api.twitch.tv/kraken | jshon -Q -e token -e client_id -u); then
    echo "Incorrect OAUTH or Twitch API down" 
    exit 1
fi

# Case Switch for functionality
case $1 in
   # Top Streams
   ts)
      echo "Top Streams"

      # Parse Twitch JSON using jshon
      $ARRAY array < <(curl -H "Client-ID: $TOKEN" -s https://api.twitch.tv/kraken/streams?limit=$LIMIT | jshon -e streams -a -e channel -e name -u -p -e game -u -p -p -e viewers)

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
      $ARRAY -t array < <(curl -H "Client-ID: $TOKEN" -s https://api.twitch.tv/kraken/games/top?limit=$LIMIT | jshon -e top -a -e game -e name -u -p -p -e viewers -u)

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

      # Step Through Array 2 at a time
      while [ $COUNTER -lt $LIMIT ]; do
         echo ${array[@]:(($COUNTER*2)):2}
         ((COUNTER++))
      done						  
   ;;
   # Else assume we are searching for a game
   *)
      echo "Top streamers for $1"

      # Convert Spaces to %20 for webcall
      GAME=${1// /%20}

      # Parse Twitch JSON using jshon
      $ARRAY -t array < <(curl -H "Client-ID: $TOKEN" -s https://api.twitch.tv/kraken/streams?limit=$LIMIT\&game=$GAME | jshon -e streams -a -e channel -e name -u -p -p -e viewers)

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
