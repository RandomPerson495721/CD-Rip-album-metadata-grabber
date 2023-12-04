#!/bin/bash

album_id=$1
email="YOUR EMAIL"
echo "You need to fill in your email for the user agent section for the musicbrainz api! Modify this script and remove lines 5 and 6."
exit
album=$(curl -s -X GET "https://musicbrainz.org/ws/2/release/$album_id?inc=recordings+artist-credits&fmt=json" -H "User-Agent: personal script to help when importing albums to Jellyfin. Contact at: $email")
first=0
album_title=$(echo $album | jq -r '.title')
current_disc=$(( $2 - 1 ))
prev_tracks=0
tmp=$(echo "$album" | jq -r '.media[1]')
i=0
total_tracks_previous_discs=0
while [[ $i < $current_disc ]]; do
    prev_tracks=$(echo "$album" | jq -r ".media[$i].tracks | length")
    total_tracks_previous_discs=$((total_tracks_previous_discs + prev_tracks))
    ((i++))
done

mkdir "$album_title"
cd "$album_title"
curl -L -o cover.jpg https://coverartarchive.org/release/{$album_id}/front
# mkdir "Disc $(( $current_disc + 1 ))"
# cd "Disc $(( $current_disc + 1 ))"
for file in "$@"; do
    if (( first < 2 )); then
        (( first += 1 ))
        continue
    fi

    thing=$(echo "$file" | grep -o '[0-9]\+')
    track_number=${thing#"${thing%%[!0]*}"}
    track=$(echo $album | jq -r '.media['$current_disc'].tracks['$((track_number - 1))']')
    track_name=$(echo $track | jq -r '.title')
    artist_names=$(echo "$track" | jq -r '.recording."artist-credit"[] | .artist.name')
    formatted_artists=$(echo "$artist_names" | paste -sd "," -)
    first_release_date=$(echo "$track" | jq -r '.recording."first-release-date"')
    file_name=$(echo "$track_name" | sed 's/\//:/g')
    (( track_number += prev_tracks ))
    ffmpeg -i "../$file" -c:a flac -metadata release_date="$first_release_date" -metadata artist="$artist_names" -metadata album="$album_title" -metadata track="$track_number" -metadata title="$track_name" "${file_name}.flac"
    metaflac --import-picture-from=cover.jpg "${file_name}.flac"
    
done
