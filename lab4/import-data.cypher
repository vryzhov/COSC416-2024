
CREATE INDEX movie_title_idx FOR (n:Movie) ON (n.title);
CREATE INDEX movie_movie_id_idx FOR (n:Movie) ON (n.movieId);
CREATE INDEX movie_imdb_id_idx FOR (n:Movie) ON (n.imdbId);
CREATE INDEX genre_name_idx FOR (n:Genre) ON (n.name);

WITH "https://raw.githubusercontent.com/vryzhov/COSC416-2024/main/lab4/" AS base
  WITH base + "movies-genre.csv" AS uri
LOAD CSV WITH HEADERS FROM uri AS row
MERGE (g:Genre{name:row.genre})
MERGE (m:Movie{movieId:toInteger(row.movieId)})
MERGE (m) -[r:IN_GENRE] ->(g)
RETURN count(*)


WITH  "https://raw.githubusercontent.com/vryzhov/COSC416-2024/main/lab4/" AS base
  WITH base + "movies-rated.csv" AS uri
LOAD CSV WITH HEADERS FROM uri AS row
MERGE (m:Movie{movieId:row.movieId})
  SET  m += {budget: toInteger(row.budget), imdbRating: toFloat(row.imdbRating),
      title:row.title, runtime: toFloat(row.runtime), revenue: toInteger(row.revenue), imdbId: row.imdbId
  }
  MERGE(u:User{name: row.userName})
  MERGE (u)-[:RATED{rating:toFloat(row.userRating), timestamp:datetime({epochseconds:toInteger(row.ratingTimestamp)}) }] -> (m)
  RETURN count(*)



WITH  "https://raw.githubusercontent.com/vryzhov/COSC416-2024/main/lab4/" AS base
  WITH base + "movies-rated.csv" AS uri
LOAD CSV WITH HEADERS FROM uri AS row
WITH row.movieId as movieId, row.released as released 
 WHERE not released = ""
MERGE (m:Movie{movieId:movieId})
  SET  m += {released: Date(released)}
  
  
