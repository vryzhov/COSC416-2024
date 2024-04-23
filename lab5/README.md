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


Before starting this assignment, consult our in-class work on recommendation engines (Week 06), paying special attention to the second lecture of that week. Your submission must include
Cypher queries, explanations of your thinking and reasoning, and the final recommendations for each of the three parts. Show all your work. Assuming of your results are correct (to some degree), thoroughness of explanations, diligence, and sound reasoning will be rewarded with extra marks. 


### Part 1

Continue building recommendation for the same user who was chosen for Lab 4.

I will demonstrate the process for the same person who was used in lab 4. Her name is Diana Robles; she watched 250 movies.

> **Note:** _You may want to attempt replicating my results first and use them as a starting point of your own investigation. The comments below are rather vague on purpose. Do not simply copy them; they are not sufficient for this lab assignment. Provide the **detailed outcome** your own work, thinking, and your own solutions to the recommendations problem._




There are at least two ways to define a peer for Diana. 

* The simplest definition is based on the count of movies they both watched. If this set forms a big part of all Diana's movies, or even if it's equal to to all movies she watches, the peers with with large subset of commonly watched movies are good candidates to generate recommendations for Diana.

*  The second is based on  Jaccard index. A user is called a peer if the Jaccard index of the movies they watched and movies watched by Diana is sufficiently high. It's not easy to come up with an universal definition of "sufficiently high," so let's define a peer as a users from the Top 10 ranked by Jaccard index. The reasoning behind using Jaccard index is the  possibility that the movies intersection comprises only a small part of movies the peer watched. In such a case, the peer may not be interested in the same type of movies as Diana. Jaccard similarity should help finding peers whose tastes are closer at the expense of smaller set of common movies.  

*  The Cypher query that computes both the size of movies' intersection and Jaccard index is rather straightforward. To obtain the top 10 peers, the results are sorted by either the intersection size, or by Jaccard index, depending on the desired peer definition. Both lists created for Diana are below.  

    
    |Peer	|peerRated|	Common	|Jaccard|
    |:------|---------:|---------:|------:|
    |Angela Garcia|1700	|173|0.0974|
    |Angela Robertson|1610|	168	|0.0993|
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
   
2. What option for the peer selection does seem preferable in your case? Explain your reasoning and your choice.  
   
5. Can we combine results of the Lab 4 (content-based recommendations) to improve the peers selection? Devise the metric to rank peers by taking into consideration genre preferences and compute the result. How does the content-based recommendations affect your choice of peers? 
 
 6. Create a tentative list of recommendations based on your investigation. Explore the list further looking for opportunities to improve the peer matching.  
 
7. Use imdbRating data as a score to rank the recommended movies    
    * _Ranking (Scoring) by imdbRating yields the final list of candidates_ 
8. Create "The Top 5 movies to watch" list    
    * _Use ORDER BY with LIMIT 5 to create recommendations_    
    * _I decided to use both the size of common movies pool and Jaccard index to crete recommendations for Diana._
    * _The results below include an additional metric of the number of peers (out of the top 5) who agreed on the recommendation (Votes column):_
    * _In my case, two movies are present in both lists_



    |Recommendation	|Score	|Votes|
    |:------|---------:|------:|
    |Band of Brothers|	9.6	|2|
    |Shawshank Redemption, The|	9.3|	4|
    |Decalogue, The (Dekalog)|	9.2	|1|
    |Pride and Prejudice|	9.1	|1|
    |Making a Murderer|	9.0	|1 | 
     **Recommendations of Top 5 peers selected by common movies count**


    |Recommendation	|Score	|Votes|
    |:------|---------:|------:|
    |Band of Brothers	|9.6	|1|
    |Shawshank Redemption, The|	9.3	|4|
    |Lord of the Rings: The Return of the King, The	|8.9	|5|
    Star Wars: Episode V - The Empire Strikes Back	|8.8	|3|
    |Fawlty Towers (1975|	8.8	|1|    
     **Recommendations of Top 5 peers selected by Jaccard index**





8. Do you see the difference between the two sets of recommendations you created for your user? Which one appears more consistent in your case? (Consistency could be understood as a measure of quality).

9. Discuss limitations of this approach. 
    * Will it work well for other users? 
    * Can it break down? What are the implicit conditions of its applicability? 
    * Other thoughts and ideas based on your understanding? 




### Part 2


This part takes into account movies ratings provided by peers. The ratings are stored as a property `rating` of `:RATED` relationship. These numbers make it possible to select peers based on the proximity of their ratings given to the movies watched by Diana. Users who rated movies similarly to Diana's ratings presumably have similar preferences and can offer better recommendations. 

* It follows that the pool of potential peers is restricted to users who watched enough movies common with Diana. Two options present themselves immeditely - either users with the large common pool, or users with the high Jaccard index. 

* The second decision to make is the choice of metric to measure movie rating similarity. The options we looked at in the class are Euclidean distance, Manhattan distance, cosine and Person similarities. Their computations are facilitated by [corresponding functions](https://neo4j.com/docs/graph-data-science/current/algorithms/similarity-functions/) from GDS library. Manhattan similarity (or distance) is not implemented, but it is reasonable to use Euclidean metric instead. 

* The third question to answer is which metric to sort by and use a score for selection of the top 5 peers. The result below shows top 5 peers closest to Diana based on the Euclidean similarity, but I might as well use any other metric. 

* The choice is not entirely arbitrary; there are some reasoning developed from understanding of data and the way these metrics relate to each other. In my case of Diana, the best Euclidean similarity of 1.0 (i.e. the Euclidean distance between the peer and Diana ratings is zero), which is  reached for three users. But each of them has only a single movie that Diana also watched. It means, we need to look at the data closer to make some compromises that hopefully will lead to sound decisions. 

* Note that I use Euclidean similarity instead of Euclidean distance. Higher values of similarity correspond to lower values of the distance, thus my results are sorted by _euclidean_ in _descending_ order.



    |Peer|peerRated|Common|Jaccard|manhattan|cosine|pearson|euclidean|
    |:------|---------:|---------:|------:|------:|------:|------:|------:|
    |Kenneth Daniels|319|52|0.1006|0.6341|0.977|0.2781|0.1544|
    |Melissa Howard|223|58|0.1398|0.6105|0.9773|0.4054|0.1404|
    |Kelsey White|307|59|0.1185|0.631|0.9777|0.5168|0.14|
    |Elizabeth Powell|422|66|0.1089|0.614|0.982|0.1415|0.1354|
    |Amy Fischer|315|55|0.1078|0.6111|0.9703|0.5401|0.1351|
    |John Swanson|231|52|0.1212|0.5876|0.9674|-0.0547|0.1307|
    |Michael Simmons|191|59|0.1545|0.596|0.9717|-0.0255|0.1297|
    |Gabriel Davila|513|66|0.0947|0.6|0.9791|0.3629|0.1256|
    |Steven Rich|341|52|0.0965|0.5746|0.9678|0.2851|0.1236|
    |Jose Miller|203|52|0.1297|0.5417|0.9812|0.3808|0.1223|
    **Peers ranked by Euclidean similarity** 


Query to test

```sql
MATCH (user:User {name: "Larry Boyd"})-[r:RATED]->(m:Movie) <-[r2:RATED] -(peer:User)
WITH user, peer, count(m) AS commonCount, collect(r.rating) as  userRatings, collect(r2.rating) as peerRatings, 
     sum((r.rating - r2.rating)^2) as euclid_dist_term,
     sum(abs(r.rating - r2.rating)) as manhat_dist_term 
CALL {with user match (user) -[:RATED] -(m:Movie) with count(distinct m) as userRatedCount return userRatedCount}
CALL {with peer match (peer) -[:RATED] -(m:Movie) with count(distinct m) as peerRatedCount return peerRatedCount}
WITH user, peer, commonCount, userRatedCount, peerRatedCount,1.0*commonCount/(userRatedCount + peerRatedCount - commonCount) as jaccard, 
    gds.similarity.pearson(userRatings, peerRatings) AS pearson_sim,
    gds.similarity.cosine(userRatings, peerRatings) AS cosine_sim,
    gds.similarity.euclidean(userRatings, peerRatings) AS euclidean_sim, 
    1.0*sqrt(sum(euclid_dist_term))/commonCount as euclidean_dist,
    1.0*sum(manhat_dist_term)/commonCount as manhattan_dist
return user.name, peer.name,  commonCount, userRatedCount,peerRatedCount, 
       jaccard, pearson_sim, cosine_sim, euclidean_sim, euclidean_dist, manhattan_dist
order by jaccard desc limit 10
```




* The list of recommendations based on this selection of peers (I am using 10 peers here) ranked by imdbRating is below. We can see some movies that were recommended earlier using different criteria of peer selection



    |Recommendation|Score|Votes|
    |:------|---------:|------:|
    |Band of Brothers|9.6|1|
    |Cosmos|9.3|2|
    |Shawshank Redemption, The|9.3|7|
    |Cowboy Bebop|9.0|1|
    |Power of Nightmares, The: The Rise of the Politics of Fear|9.0|1|
    |12 Angry Men|8.9|1|
    |Lord of the Rings: The Return of the King, The|8.9|8|
    |Star Wars: Episode V - The Empire Strikes Back|8.8|7|
    |Star Wars: Episode IV - A New Hope|8.7|8|
    |One Flew Over the Cuckoo's Nest|8.7|3


For recommendations: 

```sql
MATCH (user:User {name: "Leslie Brady"})-[r:RATED]->(m:Movie) <-[r2:RATED] -(peer:User)
WITH user, peer, count(m) AS commonCount, collect(r.rating) as  userRatings, collect(r2.rating) as peerRatings, 
     sum((r.rating - r2.rating)^2) as euclid_dist_term,
     sum(abs(r.rating - r2.rating)) as manhat_dist_term 
CALL {with user match (user) -[:RATED] -(m:Movie) with count(m) as userRatedCount return userRatedCount}
CALL {with peer match (peer) -[:RATED] -(m:Movie) with count(m) as peerRatedCount return peerRatedCount}
WITH user, peer, commonCount, userRatedCount, peerRatedCount,1.0*commonCount/(userRatedCount + peerRatedCount - commonCount) as jaccard, 
    gds.similarity.pearson(userRatings, peerRatings) AS pearson_sim,
    gds.similarity.cosine(userRatings, peerRatings) AS cosine_sim,
    gds.similarity.euclidean(userRatings, peerRatings) AS euclidean_sim, 
    1.0*sqrt(sum(euclid_dist_term))/commonCount as euclidean_dist,
    1.0*sum(manhat_dist_term)/commonCount as manhattan_dist
with user, peer,  commonCount, userRatedCount,peerRatedCount, 
   jaccard, pearson_sim, cosine_sim, euclidean_sim, euclidean_dist, manhattan_dist
order by jaccard desc limit 50 // parameter
match(peer) -[r:RATED] -(rec:Movie)
where not (user) -[:RATED] ->(rec) 
return rec.title, rec.imdbRating, count(peer) as votes, avg(r.rating)  as avgPeerRating
       order by avgPeerRating*votes desc
limit 10 // recommendations count

```



Answer following questions. Similarly to the questions in Part 1, they are concerned with the logic of our analysis and meaning of obtained results.



2. What option for the peer selection does seem preferable in your case? Explain your reasoning and your choice.  
   
1. List top 10 peers defined according to the ranking by the metric you selected. You can create multiple lists, generate recommendations and then compare them. Do they offer the same movies? How many peers vote for each of them? 
   
 6. Create a tentative list of recommendations based on your investigation. Explore the list further looking for opportunities to improve the peer matching.  
 
7. Use imdbRating data as a score to rank the recommended movies    
    * _Ranking (Scoring) by imdbRating yields the final list of candidates_ 
8. Create "The Top 5 movies to watch" list    
   


### Part 3.


* So far we have been using _imdbRating_ to score recommendations. This metric, however, is an aggregation of many IMDb users and it is likely to represent the "average" user. Since the goal of recommendations is in making them user-specific, _imdbRating_ is not the best choice for scoring. In this part of assignment, we will use movie ratings of peers to score recommendations for Diana. 


* The peer query developed in Part 2 can be enhanced to pull _rating_ attribute of _:RATED_ relationship for movies that Diana has not watched. A simple adjustment results in the following 10 recommendations. I have added the IMDb rating field for reference. 


    |Recommendation|Score|IMDb|Votes|
    |:------|---------:|------:|------:|
    |Back to the Future Part II|5.0|7.8|1|
    |Paperman|5.0|8.4|1|
    |The Intern|5.0|7.2|1|
    |Pitch Perfect|5.0|7.2|1|
    |Notebook, The|5.0|7.9|1|
    |Definitely, Maybe|5.0|7.2|1|
    |The Martian|5.0|8.1|1|
    |Cosmos|5.0|9.3|1|
    |About Time|5.0|7.8|2|
    |Prophet, A (Un Prophète)|5.0|7.9|1|
    


Create recommendations list for your user based on the peer ratings used as a score and answer the following questions. 

1. What problems can you identify for this approach? 

2. What can be done to make the score based on peer rating better? 

3. Implement your improved solution and show the result

3. How does your new way of scoring improve the "naive" approach I demonstrated?  

2. Can you think of other ways to utilize information contained in the user-generated ratings? 

### Submission

Collect all your results - Cypher queries, solutions, thoughts, conjectures, etc. - into a document, <u>**convert it to a PDF file**</u> and submit before the deadline. 


### Content based recommendations

See [Lab 4](https://github.com/vryzhov/COSC416-2024/tree/main/lab4)


