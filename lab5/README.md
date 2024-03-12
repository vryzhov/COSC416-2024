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

I will demonstrate the process for the same person who was used in lab 4. Her name is Diana Robles; she watched 250 movies.

> **Note:** _You may want to attempt replicating my results first and use them as a starting point of your own investigation. The comments below are rather vague on purpose. Do not simply copy them; they are not sufficient for this lab assignment. Provide the **detailed outcome** your own work, thinking, and your own solutions to the recommendations problem._


<!-- 
```sql
// Jaccard
match(u:User{name:"Diana Robles"}) -[r:RATED] -(m:Movie) <-[rp:RATED] - (peer:User) 
with u,peer,m
CALL{with peer match (peer) -[:RATED] -> (om:Movie) return count(distinct om) as peerRated }
with  peer, peerRated, count(distinct m) as common
return peer, peerRated, common, 1.0*common /(250 + peerRated - common) as jaccard
order by jaccard desc limit 10
```
-->

There are at least three ways to define a peer for Diana. 

* The simplest definition is based on the count of movies they both watched. If this set forms a big part of all Diana's movies, or even if it's equal to to all movies she watches, the peers with with large subset of commonly watched movies are good candidates to generate recommendations for Diana.

*  The second is based on  Jaccard index. A user is called a peer if the Jaccard index of the movies they watched and movies watched by Diana is sufficiently high. It's not easy to come up with an universal definition of "sufficiently high," so let's define a peer as a users from the Top 10 ranked by Jaccard index. The reasoning behind using Jaccard index is the  possibility that the movies intersection comprises only a small part of movies the peer watched. In such a case, the peer may not be interested in the same type of movies as Diana. Jaccard similarity should help finding peers whose tastes are closer at the expense of smaller set of common movies.  

*  The Cypher query that computes both size of the movie intersection and Jaccard index is rather straightforward. To get the top 10 peers, the results are sorted by either the intersection size, or by Jaccard index, depending and the peer definition. Both lists created for Diana are below.  

    
    |Peer	|peerRated|	Common	|Jaccard|
    |:------|---------:|---------:|------:|
    |Angela Garcia|1700	|173|0.0974|
    |Angela Robertson|1610|	168	|0.9993|
    |Karen Avila|1735|165|0.0907|
    |Darlene Garcia|2391|126|0.0501|
    |Thomas Swanson|1063|126|0.1061|
    **Peers ranked by the pool size of common movies**


    |Peer|peerRated|Common	|Jaccard|
    |:------|---------:|---------:|------:|
    |Michelle Robinson|	342	|97	|0.196 | 
    |John Nelson|253|73|	0.1698| 
    |Anita Matthews|196	|64|	0.1675| 
    |Thomas Avila|210|66	|0.1675|
    |Sierra Chandler|385|	90	|0.1651|
    **Peers ranked by Jaccard index**

* A quick look at these numbers reveals the challenge. Angela Garcia watched 173 movies out of Diana's 250 movies, which is ~70% overlap of Daina's choices. But these 173 movies are just ~10% of all movies Angela decided to watch. 

* On the other hand, Michelle and Diana have 97 common movies, or 97/250 = 38% of all Diana's movies, but the Jaccard index is substantially higher, demonstrating a close match of movie preferences of Michelle and Diana. 

Answer the following questions:
 
1. List all the peers defined according to the ranking by the size of common movies pool and Jaccard index. 
   
2. What option for the peer selection seems preferable in your case? Explain your reasoning and your choice.  
   
5. Can we combine results of the Lab 4 (content-based recommendations) to improve the peers selection? Devise the metric to rank peers taking into consideration genre preferences and compute the result. How does the content-based recommendations affect your choice of peers? 
 
 6. Create a tentative list of recommendations based on your investigation. Explore the list further looking for opportunities to improve peer matching.  
 
7. Use imdbRating data as a score to rank the recommended movies    
    * _Ranking (Scoring) by imdbRating yields the final list of candidates_ 
8. Create "The Top 5 movies to watch" list    
    * _Use ORDER BY with LIMIT 5 to create recommendations_    
    * _I decided to use both the size of common movies pool and Jaccard index to crete recommendations for Diana._
    * _Here are the results with additional metric showing the number of peers (out of the top 5) who agreed on the recommendation (Votes column):_
    * _In my case, two movies are present in both lists_



    |Recommendation	|Score	|Votes|
    |:------|---------:|------:|
    |Band of Brothers|	9.6	|2|
    |Shawshank Redemption, The|	9.3|	4|
    |Decalogue, The (Dekalog)|	9.2	|1|
    |Pride and Prejudice|	9.1	|1|
    |Making a Murderer|	9.0	|1 | 
     **Recommendations by Top 5 peers selected by common movies count**


    |Recommendation	|Score	|Votes|
    |:------|---------:|------:|
    |Band of Brothers	|9.6	|1|
    |Shawshank Redemption, The|	9.3	|4|
    |Lord of the Rings: The Return of the King, The	|8.9	|5|
    Star Wars: Episode V - The Empire Strikes Back	|8.8	|3|
    |Fawlty Towers (1975|	8.8	|1|    
     **Recommendations by Top 5 peers selected by Jaccard index**



<!--
match (diana:User{name:"Diana Robles"}) 
match(peer:User) -[r:RATED] - (rec:Movie)
where peer.name IN ["Michelle Robinson", "John Nelson", 'Anita Matthews',
 'Thomas Avila','Sierra Chandler'] 
   and not (diana) -[:RATED] -> (rec)
   and not rec.imdbRating is null
return  rec.title as Recommendation, 
       rec.imdbRating as Score, count(peer) as Votes
 order by rec.imdbRating desc limit 5
```sql
-->

8. Do you see the difference between these two sets of recommendations? Which one appears more consistent in your case? (Consistency could be understood as a measure of quality).

9. Discuss limitations of this approach. 
    * Will it work well for other users? 
    * Can it break down? What are the implicit conditions of its applicability? 
    * Other thoughts based on your understanding? 



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


### Content based recommendations

See [Lab 4](https://github.com/vryzhov/COSC416-2024/tree/main/lab4)


