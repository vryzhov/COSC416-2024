# Lab 5: Recommendation Engines II. Collaborative Filtering


## Introduction

Your goal of this Lab is building a movie recommendation engine using collaborative filtering approach. 

This lab assumes your familiarity with the class material of Week 06. 

## Setup


This lab is based on the Movies database created for Lab 4


## Collaborative Filtering 

>_"Use the preferences, ratings and actions of other users in the network to find items to recommend"_


> _Collaborative filtering approaches build a model from a user's past behavior (items previously purchased or selected and/or numerical ratings given to those items) as well as similar decisions made by other users. This model is then used to predict items (or ratings for items) that the user may have an interest in.  (Wikipedia)_



The collaborative filtering in this assignment will rely on the user similarities. Users whose preferences are aligned with the user chosen for recommendations are called *peers*. Once the peers are identified,
the recommendations are created by selecting movies watched by peers but not have been watched by the user. The ranking will be done based on the 
user and peers similarity metrics, and the peer ratings of the candidate movies.


Today's assignment consists of three parts. 
<!-- 
 In the first part, only information of watched (and rated) movies is available; in the second part we have access to the ratings assigned to movies that the user watched previously. These ratings are used to learn user preferences for movies of different genres. The third part is an attempt to combine results of the first and the second parts and create a more robust representation of user's preferences. As described earlier, the recommendations are created by selecting movies from the most preferred genre(s) under the condition that they have not yet been watched. The final recommendations are ranked by the `imdbRating` field that is used as score.  Only the top 5 movies are recommended to the user to watch.
-->

Before starting this assignment, consult our in-class work on recommendation engines (Week 06), paying special attention to the second lecture of that week. Your submission must include
Cypher queries, explanations of your thinking and reasoning, and the final recommendations for each of the three parts. Show all your work. Assuming of your results are correct (to some degree), thoroughness of explanations, diligence, and sound reasoning will be rewarded with extra marks. 


### Part 1

Continue building recommendation for the same user who was chosen for Lab 4.

I will demonstrate building recommendations for the same person who was used in lab 4. Her name is Diana Robles; she watched 250 movies.

> **Note:** _You may want to attempt replicating my results first and use them as a starting point of your own investigation. The comments below are rather vague on purpose. Do not simply copy them; they are not sufficient for this lab assignment. Provide the **detailed outcome** your own work, thinking, and your own solutions to the recommendations problem._

<!-- 
Answer the following questions:
 
1. What is his/her name and how many movies did he/she rated?    
    * _Diana Robles rated 250 movies_
2. What movie genres did she prefer watching?     
    * _She watched over a hundred of Comedies and Dramas_    
    *  _Movies of Action, Crime and Thriller genres are not too far behind_
2. Explain your decision for preferred genres and justify your choice     
    * _Action, Drama, Comedy, and Thriller are movies she seems to like watching_
    * _They are also the most frequent genres in the data set_    
    * _This imbalance creates a bias for users who can pick a movie to watch arbitrarily_     
    * _A significant presence of these genres in her watch list could be the result of this bias_
5. What genres are the best candidates to create recommendations?     
    * _I have decided to use a few genres that seem to be a reasonable choice_
6. Create a tentative list of recommendations based on the user preferred genres    
    * _The selected genres have enough movies to create recommendations_
7. Use imdbRating data as a score to rank the recommended movies    
    * _Ranking (Scoring) by imdbRating yields the final list of candidates_ 
8. Create "The Top 5 movies to watch" list    
    * _Use ORDER BY with LIMIT 5 to create recommendations_    
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
    * Can it break down? What are the implicit conditions of its applicability? 
    * How to compensate the bias caused by the uneven representation of genres in the database? 
    * Should this bias be compensated? Discuss pro and contra arguments. 
    * Other thoughts based on your understanding? 

--> 

### Part 2


This part takes into account movies ratings provided by peers. The ratings are stored as a property `rating` of `:RATED` relationship. These numbers make it possible to select movies the peers rated above their average rating. They are presumable a good choice for Diana's recommendations. 

With this plan in mind, you will answer the following questions for the user's peers you chose in Part 1. 

<!--

1. What is the average rating of movies the user watched?
    * _Average rating of all movies Diana watched is 3.17_
4. What is the average rating per genre? 
    * _The highest average rating of 3.63 is reached for "Western"_    
    * _The next three genres are "War" (3.43), "Sci-Fi" (3.3), and "Musical" (3.3)_.
5. What genres are the best candidates for recommendations based on the movie ratings? 
    * _Based on these results, the best genres to use for recommendations are "Western" and "War"_
6. Create a tentative list of recommended movies based on the average ratings
    * _There are enough movies in these categories available for recommendations_
7. Use `imdbRating` data as a score to rank the recommended movies
    * _Using `imdbRating` as a ranking score leads to the list of top movies to recommend_
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
    * Similarly to the Part 1, the decisions we made are biased. Explain the nature of this bias. Should we attempt to compensate for it? 
 
--> 
### Part 3

<!-- 
Now we have two versions of content-based recommendation methods. It's time to think about their differences and applicability. 

Answer the following questions.

1. How do the recommendations obtained in Part 1 and Part 2 differ? 
2. Discuss possible reasons for these differences. 
3. What approach would work better in the real-life scenario? Why?  
5. Come up with a better way to create recommendations by combining both methods. 
6. Merge Cypher queries of Part 1 and Part 2 to create the final list of recommendations

-->

### Submission

Collect all your results - Cypher queries, solutions, thoughts, conjectures, etc. - into a document, <u>**convert it to a PDF file**</u> and submit before the deadline. 




