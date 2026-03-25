const axios = require('axios');

async function searchYouTubeVideos({ query, maxResults = 5 }) {
  const apiKey = process.env.YOUTUBE_API_KEY;
  if (!apiKey) {
    throw new Error('YOUTUBE_API_KEY is not configured');
  }

  const { data } = await axios.get('https://www.googleapis.com/youtube/v3/search', {
    params: {
      part: 'snippet',
      q: query,
      maxResults,
      type: 'video',
      videoEmbeddable: 'true',
      videoSyndicated: 'true',
      key: apiKey,
      safeSearch: 'moderate'
    },
    timeout: 20000
  });

  return (data.items || []).map((item) => ({
    videoId: item.id.videoId,
    title: item.snippet.title,
    description: item.snippet.description,
    thumbnail: item.snippet.thumbnails?.high?.url || item.snippet.thumbnails?.default?.url,
    channelTitle: item.snippet.channelTitle,
    publishedAt: item.snippet.publishedAt,
    url: `https://www.youtube.com/watch?v=${item.id.videoId}`
  }));
}

module.exports = {
  searchYouTubeVideos
};
