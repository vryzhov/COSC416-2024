# Lab 4: Recommendation Engine


## Introduction

Your goal for this up building a movie recommendation engine. In class, we studied two types of filtering used for such engines -  one is the content-based filtering, and the second is collaborative filtering. You will build two engines using each of these.  Check the material for Week 06.


## Setup

1. Create a new Neo4j DBMS or use an existing one to create a new database. 
1. Make sure both *APOC* and *GDS* libraries are available in this DBMS.
2. Import required data by running the following statements in Neo4j Browser. 
    - This code is saved in the file `import-data.cypher`. 

```sql 
// Create necessary indices to speed up the load
CREATE INDEX movie_title_idx IF NOT EXISTS FOR (n:Movie) ON (n.title);
CREATE INDEX movie_movie_id_idx IF NOT EXISTS FOR (n:Movie) ON (n.movieId);
CREATE INDEX movie_imdb_id_idx IF NOT EXISTS FOR (n:Movie) ON (n.imdbId);
CREATE INDEX genre_name_idx IF NOT EXISTS FOR (n:Genre) ON (n.name);
CREATE INDEX user_name_idx  IF NOT EXISTS FOR (n:User) ON (n.name);

// Import genres and movies
WITH 'https://raw.githubusercontent.com/vryzhov/COSC416-2024/main/lab4/' AS base
  WITH base + "movies-genre.csv" AS uri
LOAD CSV WITH HEADERS FROM uri AS row
MERGE (g:Genre{name:row.genre})
MERGE (m:Movie{movieId:toInteger(row.movieId)})
  SET m += {budget: toInteger(row.budget), imdbRating: toFloat(row.imdbRating),
      title:row.title, runtime: toFloat(row.runtime), 
      revenue: toInteger(row.revenue), imdbId: row.imdbId
  }
MERGE (m) -[r:IN_GENRE] ->(g)
RETURN count(*);  // 20340

// Import released dates 
WITH  'https://raw.githubusercontent.com/vryzhov/COSC416-2024/main/lab4/' AS base
  WITH base + "movies-genre.csv" AS uri
LOAD CSV WITH HEADERS FROM uri AS row
WITH row.movieId as movieId, row.released as released 
 WHERE not released = ""
MERGE (m:Movie{movieId:toInteger(movieId)})
  SET  m += {released: Date(released)}
RETURN count(*);  // 20158  
 
// Import user and ratings
WITH  'https://raw.githubusercontent.com/vryzhov/COSC416-2024/main/lab4/' AS base
  WITH base + "movies-rated.csv" AS uri
LOAD CSV WITH HEADERS FROM uri AS row
MERGE (m:Movie{movieId:toInteger(row.movieId)})
MERGE(u:User{name: row.userName})
MERGE (u)-[:RATED{rating:toFloat(row.userRating), timestamp:datetime({epochseconds:toInteger(row.ratingTimestamp)}) }] -> (m)
RETURN count(*);  // 100004

```

There are three types of nodes - User, Movie, and Genre. The data model is shown below.  

<img title="Schema" alt="Schema" src="schema.png" width="300">

Available nodes' attributes are clear from the data loading script.


## Content based filtering

>_"Recommend items that are similar to those that a user is viewing, rated highly or purchased previously."_


> _Content-based filtering uses item features to recommend other items similar to what the user likes, based on their previous actions or explicit feedback.  (Wikipedia)_


The only item feature available in this data set is the movie Genres. There are 20 distinct  Genres, and a movie can be associated with any number of them. The highest count of genres a movie is associated with happens to be _10_, reached for the movie "Rubber". 


Therefore, the content based filtering in this assignment will rely relies on the user preferences for movies that belong to certain genres. Once the most favorable genres of a given user are identified, the recommendations are created by sampling movies of these genres from the collection unwatched movies, and ranking them by some criteria. As a good example of ranking, we will use the Movie property _imdbRating_. It is a float number ranging between _0_ and _10_. The higher the ranking, the "better" the movie. Thus, the problem of content-based filtering is reduced to identification of user-specific genres with the movies deemed most suitable for recommendation. 


The assignment consists of three parts.  In the first part, only information of watched (and ranked) movies is available; in the second part we have access to the user's movie ratings. These rankings will be used to learn user preferences for movies of certain genres. The third part is an attempt to combine the results of first two parts and to create a more robust representation of user's genre preferences. As described earlier, the recommendations are created by sampling movies from the most preferred genre(s) under the condition that they have not yet been watched. The final recommendations are ranked by the _imdbRating_ field and only the top 5 movies are then offered to the user for watching.


Before starting on this assignment, consult our in-class work on recommendation engines (Week 06), especially paying attention to the second lecture. Your submission must include
Cypher queries you use to solve the content-based recommendation problem, your reasoning, and the recommendations. Show all your work. I will reward marks for thoroughness of explanations, diligence, and sound reasoning. 


### Part 1

Pick up a user who watched and rated at least 300 movies. This is the user you will be building the movie recommendations for. I will use "Diana Robles" for demonstration. She watched 250 movies and is not a suitable choice for this assignment. 

Answer the following questions:
 
1. How many movies did he/she rated?    
    * _Diana rated 250 movies_
2. What movie genres did they prefer watching?     
    * _She watched over a hundred of Comedies and Dramas,_    
    *  _Action, Crime and Thriller are not too far behind_
2. Explain your decision for preferred genres and justify your choice     
    * _Action, Drama, Comedy, and Thriller are the most frequent genres in the data_    
    * _This imbalance creates a bias for users to pick up movies to watch_     
    * _Significant presence of these genres in her watch list could be the result of the bias_
5. What genres are the best candidates to create recommendations?     
    * _I have decided to use several genres_
6. Create a tentative list of recommendations based on the user preferred genres    
    * _The selected genres have enough movies for her to choose from_
7. Use imdbRating data as a score to rank the recommended movies    
    * _Ranking (Scoring) by imdbRating yields the list of candidates_ 
8. Create "The Top 5 movies to watch" list    
    * _Use ORDER BY with LIMIT 5_    
    * _Recommendations for Diana:_

        |Recommendation| 	Score | Genres |
        |:---------------|---------:|------ |
        |Knockin' on Heaven's Door|	8.0|["Comedy", "Crime", "Drama", "Action"]|
        |Pek Yakında	|7.9|["Comedy", "Action", "Drama"]|
        |Absolute Giganten |	7.8|["Action", "Comedy", "Romance", "Drama"]
        |Lethal Weapon|	7.6|["Comedy", "Action", "Crime", "Drama"]
        |Sonatine (Sonachine)|	7.6|["Action", "Crime", "Drama", "Comedy"]
        
9. Discuss limitations of this approach. 
    * Will it work well for other users? 
    * When can it break altogether? 
    * How to compensate the bias caused by the uneven representation of genres in the database? 
    * Should this bias be compensated?     
    * Other thoughts? 



<!--
```sql
match(u:User{name:"Diana Robles"}) -[r:RATED] -(m:Movie) -[:IN_GENRE] ->(g:Genre)
call { match(m:Movie) -[:IN_GENRE] ->(gn:Genre) 
      return gn.name as genre, count(m) as mvTotal 
      }
with mvTotal, genre, g.name as genre2, count(m) as mvWatched, 
     avg(1.0*r.rating) as avgRating 
where genre2 = genre
return genre, mvTotal, mvWatched, 1.0*mvWatched/mvTotal as watchedProp,  avgRating,
       1.0*mvWatched*avgRating/mvTotal as weight
order by mvWatched desc

// Recommendations
match (diana:User{name:"Diana Robles"}) 
match(m) -[r:IN_GENRE] - (:Genre{name:"Drama"})
  where (m) -[:IN_GENRE] -> (:Genre{name:"Comedy"})
   and  (m) -[:IN_GENRE] -> (:Genre{name:"Action"})
   and not (m) <-[:RATED] - (diana)
   and not m.imdbRating is null
with m as rec
match (rec) -[:IN_GENRE] -(g:Genre)
return rec.title as Recommendation, 
       rec.imdbRating as Score,
       COLLECT(Distinct g.name) as Genres
 order by rec.imdbRating desc limit 5

```
-->


### Part 2

This part takes into account the user rating of movies. All 250 movies watched by Diana has her ratings ranging from _1.0_ to _5.0_ and stored as a property `rating` of `:RATED` relationship. These numbers make it possible to define her preferences for movie genres not based on the count of movies but on their ratings. We will compute average ratings for each genre and use these numbers to select best genres used for recommendations. 

With this plan in mind, you will answer the following questions for the user you picked in Part 1

1. What is the average rating of movies the user watched?
    * _Average rating of all watched movies is 3.17_
4. What is the average rating per genre? 
    * _The highest average rating of 3.63 is reached for "Western"_    
    * _The next three genres are "War" (3.43), "Sci-Fi" (3.3), and "Musical" (3.3)_.
5. What genres are the best candidates for recommendations based on the movie ratings? 
    * _Based on these results, the best genres to use for recommendations are "Western" and "War"_
6. Create a tentative list of recommended movies based on the average ratings
    * _There are enough movies in these categories available for recommendations_
7. Use imdbRating data as a score to rank the recommended movies
    * _Using imdbRating as a ranking score leads to the list of top movies to recommend_
8. Create "The Top 5 movies to watch" list
    * _Use ORDER BY and LIMIT to create recommendations_
    * _Recommendations for Diana according to the analysis of her movie ratings_

        |Recommendation| 	Score | Genres |
        |:---------------|---------:|------ |
        |Shenandoah|	7.4 |	["War", "Western", "Drama"] 
        |Legends of the Fall| 7.5| 	["War", "Drama", "Western", "Romance"]
        |Two Mules for Sister Sara |	7.0	|["War", "Western", "Comedy"]
        |Alamo, The |	6.9	|["Drama", "Western", "Action", "War"]
        |Australia |	6.6	|["Adventure", "Western", "Drama", "War"]


9. Discuss limitations of this approach.
    * What can make this approach break or render it less reliable or accurate? 
    * Similarly to the Part 1, the decisions we made are biased. Explain the nature of this bias. 
 

<!-- 
```

// All movies average rating
match (diana:User{name:"Diana Robles"}) -[r:RATED] -> (m:Movie) 
 return  min(r.rating), max(r.rating), round(avg(r.rating), 2)  as avg , count(m.title) as x
 order by avg desc

// Genre specific average ratings
match (diana:User{name:"Diana Robles"}) -[r:RATED] -> (m:Movie) -[:IN_GENRE] - (g:Genre)
 return g.name, min(r.rating), max(r.rating), round(avg(r.rating), 2)  as avg , count(m.title) as x
 order by avg desc

// Recommendations
match (diana:User{name:"Diana Robles"}) 
match(m) -[r:IN_GENRE] - (:Genre{name:"Western"})
  where (m) -[:IN_GENRE] -> (:Genre{name:"War"})
   and not (m) <-[:RATED] - (diana)
   and not m.imdbRating is null
with m as rec
match (rec) -[:IN_GENRE] -(g:Genre)
return rec.title as Recommendation, 
       rec.imdbRating as Score,
       COLLECT(Distinct g.name) as Genres
 order by rec.imdbRating desc limit 5

```
-->

### Part 3

Answer the following questions.

1. How do the recommendations obtained in Part 1 and Part 2 differ? 
2. Explain the difference. 
3. What approach would work better? Why?  
5. Come up with a better way to create recommendations by combining both approaches. 






## Collaborative filtering




