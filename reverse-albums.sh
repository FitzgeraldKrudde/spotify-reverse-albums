#
# This script creates a new playlist in your account with all the albums of an artist reversed.
# This is convenient when you want play albums reverse chronoligically (oldest first) as the albums are usually sorted with newest first.
# Currently (April 2023) the Spotify clients do not enable you to play a playlist albums in reversed order.
#
# Just invoke this script without parameters to get the usage.
#
#
# Fitzgerald April 2023
#

# This scripts has a few dependencies on some (standard Linux) commands:
# base64
# jq
# curl
# nc
# tac

#
# The script will check for these dependencies.
#

#
# The source for this script is on Github: https://github.com/FitzgeraldKrudde/spotify-reverse-playlist
#

#
# Spotify application ID (reverse-playlist)
#
CLIENT_ID="c6ca1fca1b374acb857021f5907d8ea5"
CLIENT_SECRET="3cfe8ca8492f4db0a49e85dde5af34d7"

#
# base64 clientid/clientsecret
#
b64_client_id_secret=$(echo -ne "${CLIENT_ID}":"${CLIENT_SECRET}" | base64 --wrap=0)

#
# listen port for nc callback
#
PORT=8888
#
# redirect URL after providing access
#
REDIRECT_URI="http://localhost:${PORT}"

newline=$'\n'

#
# Spotify REST stuff
#
SPOTIFY_API_TOKEN="https://accounts.spotify.com/api/token"
SPOTIFY_API_AUTHORIZE="https://accounts.spotify.com/authorize/"
SPOTIFY_API_BASE_URL="https://api.spotify.com/v1"
SPOTIFY_API_ME_URL="${SPOTIFY_API_BASE_URL}/me"
SPOTIFY_API_SCOPES=$(echo "playlist-read-private playlist-modify-public playlist-modify-private user-read-private" | tr ' ' '%' | sed s/%/%20/g)
SPOTIFY_ACCEPT_HEADER="Accept: application/json"
SPOTIFY_CONTENT_TYPE_HEADER="Content-Type: application/json"
CURL_OPTIONS="--silent"
#CURL_OPTIONS=""

#
# functions
#
usage() {
	echo "usage: $0 <artist-id> [new-playlist-name] [new-playlist-description]"
	echo ""
	echo "This script reverses the albums of an artist."
	echo "The only required parameter is artist-id."
	echo "A new playlist in your account will be created with the albums reversed."
	echo ""
	echo "For the new playlist the default name/description is:"
	echo "name: 'albums of <artist_name> in reverse order'"
	echo "description: 'albums of <artist_name> in reverse order'"
	echo "If you want to use something else then provide the parameters."
	echo ""
	echo "The easiest way to find the artist-id:"
	echo "use the Spotify web player (https://open.spotify.com) and go to an artist."
	echo "For example: https://open.spotify.com/artist/0k17h0D3J5VfsdmQ1iZtE9"
	echo ""
	echo "artist-id -> 0k17h0D3J5VfsdmQ1iZtE9"
}

checkForErrorInResponse() {
	local response=$1
	local error=$(echo ${response} | jq --raw-output '.error')
	if [[ "${error}" != "null" ]]
	then
		echo "failed with the following error:"
		echo "${error}"
		echo "exiting.."
		exit 1
	fi
}

checkForBinary() {
	local cmd=$1
	if ! which $cmd > /dev/null
	then
		echo "missing binary: $cmd"
		echo "exiting..."
		exit 2
	fi
}

#
# /functions
#

#
# start script
#

#
# check for prerequisite binaries
#
checkForBinary base64
checkForBinary jq
checkForBinary curl
checkForBinary nc
checkForBinary tac

#
# check for required parameter artist_id
#
if [[ "${#}" -lt "1" ]]
then
	usage
	exit 1
else
	artist_id="${1}"
	echo "artist_id: $artist_id"
fi

#
# read optional parameters
# 
if [[ -n $2 ]]
then
	destination_playlist_name="${3}"
	echo "destination_playlist_name: $destination_playlist_name"
fi
if [[ -n $3 ]]
then
	destination_playlist_description="${4}"
	echo "destination_playlist_description: $destination_playlist_description"
fi

#
# send the user to the Spotify URL for authorization
#
authorization_endpoint="${SPOTIFY_API_AUTHORIZE}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SPOTIFY_API_SCOPES}"
echo "Go to this URL to authorize this script: $authorization_endpoint"
echo "After authorization this script will pickup the authorization code"
response=$(echo -e 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 0\r\nAccess-Control-Allow-Origin:*\r\nConnection: Close\r\n\r\nDone!\r\n\r\n\r\n' | nc -l -p "${PORT}")
authorization_code=$(echo "${response}" | grep GET | cut --delimiter=' ' -f 2 | cut --delimiter='=' -f 2)
echo "Got authorization code: ${authorization_code}"

#
# get a Spotify access token for this authorization code
#
response=$(curl ${CURL_OPTIONS} --header "Content-Type:application/x-www-form-urlencoded" --header "Authorization: Basic $b64_client_id_secret" --data "grant_type=authorization_code&code=${authorization_code}&redirect_uri=${REDIRECT_URI}" ${SPOTIFY_API_TOKEN})
checkForErrorInResponse "${response}"
spotify_access_token=$(echo "${response}" | jq --raw-output '.access_token')

#
# define the Spotify authorization header
#
spotify_authorization_header="Authorization: Bearer ${spotify_access_token}"

#
# get the artist name
#
response=$(curl ${CURL_OPTIONS} --header "${SPOTIFY_ACCEPT_HEADER}" --header "${spotify_authorization_header}" "${SPOTIFY_API_BASE_URL}/artists/${artist_id}")
checkForErrorInResponse "${response}"
artist_name=$(echo ${response} | jq --raw-output '.name')
echo "looking for artist: ${artist_name}"

#
# get info for the current Spotify user
#
response=$(curl ${CURL_OPTIONS} --header "${SPOTIFY_ACCEPT_HEADER}" --header "${spotify_authorization_header}" "${SPOTIFY_API_ME_URL}")
checkForErrorInResponse "${response}"
current_spotify_user=$(echo ${response} | jq --raw-output '.display_name')
echo "current_spotify_user: ${current_spotify_user}"
current_spotify_user_id=$(echo ${response} | jq --raw-output '.id')
echo "current_spotify_user_id: ${current_spotify_user_id}"

#
# get the artist albums
#
response=$(curl ${CURL_OPTIONS} --header "${SPOTIFY_ACCEPT_HEADER}" --header "${spotify_authorization_header}" "${SPOTIFY_API_BASE_URL}/artists/${artist_id}/albums?include_groups=album&limit=50")
checkForErrorInResponse "${response}"
nr_albums="$(echo ${response} | jq --raw-output '.items |  length')"
echo ""
echo "found ${nr_albums} albums:"
echo "$(echo ${response} | jq --raw-output '.items | .[] | .name + " " + .release_date + " (id: " + .id + ")" ')"
echo ""
artist_album_ids=$(echo ${response} | jq --raw-output '.items | .[] | .id')

# set name of the new playlist based on the artist name (if a name has not been provided on the commandline)
#
if [[ -z ${destination_playlist_name} ]]
then
	destination_playlist_name="albums of ${artist_name} in reverse order"
fi

#
# set description of the new playlist based on the artist name (if a name has not been provided on the commandline)
#
if [[ -z ${destination_playlist_description} ]]
then
	destination_playlist_description="albums of ${artist_name} in reverse order"
fi

#
# create the new playlist
#
body=$(jq --null-input --arg name "${destination_playlist_name}" --arg description "${destination_playlist_description}" '{name:$name, description:$description, public:true}')
response=$(curl ${CURL_OPTIONS} --request POST "${SPOTIFY_API_BASE_URL}/users/${current_spotify_user_id}/playlists" --header "${SPOTIFY_ACCEPT_HEADER}" --header "${spotify_authorization_header}" --header "${SPOTIFY_CONTENT_TYPE_HEADER}" --data "${body}")
checkForErrorInResponse "${response}"
destination_playlist_id=$(echo ${response} | jq --raw-output '.id')
destination_playlist_url=$(echo ${response} | jq --raw-output '.external_urls.spotify')
echo "Created a new playlist, id: ${destination_playlist_id}"

#
# add all albums to the new playlist
#
echo "${artist_album_ids}" | tac | while read album_id
do
	#
	# get the tracks for the album
	#
	echo -e "album_id: ${album_id} \c"
	response=$(curl ${CURL_OPTIONS} "${SPOTIFY_API_BASE_URL}/albums/${album_id}/tracks?limit=50" --header "${SPOTIFY_ACCEPT_HEADER}" --header "${SPOTIFY_CONTENT_TYPE_HEADER}" --header "${spotify_authorization_header}") 
	checkForErrorInResponse "${response}"
	album_tracks="$(echo ${response} | jq --raw-output '.items[].uri' | xargs)"
	echo -e "#retrieved tracks: $(wc -w <<< ${album_tracks}) \c"

	#
	# add the tracks to the new playlist
	#
	body=$(echo "\"${album_tracks}\"" | jq 'split(" ") as $tracks | {uris:$tracks}')
	response=$(curl ${CURL_OPTIONS} --request POST "${SPOTIFY_API_BASE_URL}/users/${current_spotify_user_id}/playlists/${destination_playlist_id}/tracks" --header "${SPOTIFY_ACCEPT_HEADER}" --header "${SPOTIFY_CONTENT_TYPE_HEADER}" --header "${spotify_authorization_header}" --data "${body}") 
	checkForErrorInResponse "${response}"
	echo "added to playlist"
done

#
# finished
#
echo ""
echo "Finished successfully. URL of the new playlist: ${destination_playlist_url}"


