require 'scrobbles/to_tracks'
require 'users/helpers/retrieve_spotify_user'

class ScrobbleTracks
  include Sidekiq::Worker

  NUM_TRACKS = 5

  def perform(user_id)
    recent_tracks = Users::Helpers::RetrieveSpotifyUser.new.call(user_id: user_id).recently_played(limit: NUM_TRACKS)

    get_scrobble_difference(recent_tracks, user_id).each do |track|
      add_scrobble(user_id, track.id)
    end
  end

  private

  def get_scrobble_difference(recent_tracks, user_id)
    saved_scrobbles = last_saved_scrobbles(user_id)

    saved_tracks = Scrobbles::ToTracks.new.call(scrobbles: saved_scrobbles)

    remove_duplicates(recent_tracks, saved_tracks)
  end

  def remove_duplicates(recent_tracks, saved_tracks)
    recent_tracks.select do |track|
      !track_list_includes?(track, saved_tracks)
    end
  end

  def track_list_includes?(track, track_list)
    return_value = false
    track_list.each do |track_from_list|
      if track.name == track_from_list.name && track.artists.first.name == track_from_list.artists.first.name
        return_value = true
        break
      end
    end

    return_value
  end

  def add_scrobble(user_id, track_id)
    Scrobble.create(user_id: user_id, track_id: track_id)
  end

  def last_saved_scrobbles(user_id)
    if Scrobble.where(user_id: user_id).exists?
      scrobbles = Scrobble.where(user_id: user_id).order('created_at desc').limit(NUM_TRACKS)
    else
      scrobbles = []
    end

    scrobbles.select do |scrobble|
      Time.now.utc > scrobble.created_at.utc - 20.minutes
    end
  end
end
