# Lab 6: Recommendation Engines III. Recommendations quality

# Introduction

Your goal of this Lab is tgh use of GDS algorithms for recommendations and subsequent 
estimation of their relevance to the user of interest. 

This lab assumes your familiarity with the class material. 

# Setup


This lab is based on the Movies database created for Labs 4 and 5


# GDS


The first part of the lab is concerned with the use of GDS algorithms `FastRP` and `kNN`.  Execute the queries below in sequence. Feel free to use _.estimate_   if there are concerns related to the CPU/Memory resources available

## Step 1. Create GDS Projection

Create native GDS projection "Peers" for nodes *Movie*, *User* and relationships *RATED*. Make relationships undirected and 

```sql
CALL gds.graph.project("Peers", 
  ['Movie', 'User'], 
  { RATED:{orientation: "UNDIRECTED"}}
)
YIELD *
```

## Step 2. Create embedding with FastRP 

Use FastRP embedding algorithm to project "Peers" to a subspace of lower dimension. The graph hs abo 10,000 nodes. I will use 64-dimensional embedding space. The rule of thumbs for selection of dimensionality _k_ is that _k_ << _ln(N)_ where _N_ is the number of data points and _ln()_ is natural logarithm. In our case, points are graph nodes, and _ln(10000)_ is about *10*, which is six time less than the dimension of embedding space. 

* The result  of the algorithm are written to the projected nodes (mutated) as 64-long lists of floats (vectors) stored as an attrubute _embedding_.  
* The count of iterations is *4* (User->Movie->User-Movie) with
weights _[0,1,1,1]_
* Setting parameter *randomSeed* to a constant value guarantees replicability of the obtained results. 

```sql
CALL gds.fastRP.mutate (
     "Peers", 
    { embeddingDimension:64, 
      IterationWeights: [0.0,1.0,1.0,1.0], 
      randomSeed:7474,
      mutateProperty: "embedding"
    }) YIELD *
```

## Step 3. Identify top 5 peers using kNN node similarity algorithm

The results of kNN algorithm will be written to the graph (not to the projection "Peer") in the form of new relationship "PEER" between "Users" with the property _score_ that indicate the strength of similarity between connected User nodes. This is a float number. I am going to use Top 5 peers. Note t


```sql
CALL gds.knn.write("Peers", 
 { nodeLabels:["User"],  
 nodeProperties:"embedding", topK:5,
 writeRelationshipType: "PEER",
 writeProperty: "score"})
YIELD *;
// Check
// match(u) -[r:PEER] - (o) return * limit 20
```

## Step 4. Recommendations

At this point, we are in the situation of collaborative filtering and can use 
the same approach as we have in Lab 5. 
Note that
the "similarity" relation is symmetric and I use  :PEER as a non-directional relationship. 
By doing so, each node is attached to the higher number of peers under consideration (more than 5 in most cases)


Here is an illustration of Diana'a peers. The relationships go from Diana to her 5 peers but there is also a relationship  from Stacy to Diana that goes in opposite direction. By ignoring directionality, Stacy will be considered Diana' peer as well

```sql
MATCH (diana:User where diana.name IN ["Diana Robles"]) 
      -[p:PEER] -(o) 
RETURN * 
```
<img title="Diana peers" alt="Diana" src="diana-5peers.png" width="400">


Peers neighborhood of Diana and Stacy can be retrieved by the query 

```sql
MATCH (diana:User where diana.name IN ["Diana Robles", "Stacy Grant"]) 
      -[p:PEER] -(o) return * 
```

<img title="Diana neighborhood" alt="Daina neighbors" 
 src="diana-neighbors.png" width="400">


Now we are ready to check recommendations these peers offer. 
There are several options to consider.



### Option 4.1. average peer ratings only

Take all movies rated by the peers and rank them by peers' ratings. 

```sql
MATCH(diana:User{name:"Diana Robles"})
CALL { WITH diana 
      MATCH (diana)-[:PEER] - (peer:User) - [rate:RATED] ->(m:Movie)
      RETURN  m, rate, peer 
      ORDER BY  peer.score   DESC,  // peer similarity -- most similar peers first
                rate.rating  DESC   // peer rating     -- then their ratings
              }
WITH * 
WHERE NOT (diana)-[:RATED] -(m)
RETURN  m.title              AS title,  
   ROUND(AVG(rate.rating),2) AS peerRating, // average peer rating
   COUNT(DISTINCT peer) AS votes,           // votes
   m.imdbRating         AS imdbRating       // imdbRating as is
ORDER BY peerRating * votes DESC            // measure of film quality
LIMIT 10
```
The output: 

<pre>
╒════════════════════════════════════════════════╤══════════╤═════╤══════════╕
│title                                           │peerRating│votes│imdbRating│
╞════════════════════════════════════════════════╪══════════╪═════╪══════════╡
│"Shawshank Redemption, The"                     │4.6       │5    │9.3       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Bourne Identity, The"                          │4.1       │5    │7.9       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Star Wars: Episode IV - A New Hope"            │3.6       │5    │8.7       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"There Will Be Blood"                           │4.5       │4    │8.1       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Silence of the Lambs, The"                     │4.5       │4    │8.6       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"City of God (Cidade de Deus)"                  │4.38      │4    │8.7       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Star Wars: Episode V - The Empire Strikes Back"│4.38      │4    │8.8       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Toy Story"                                     │4.38      │4    │8.3       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Kung Fu Panda"                                 │4.25      │4    │7.6       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Collateral"                                    │4.25      │4    │7.6       │
└────────────────────────────────────────────────┴──────────┴─────┴──────────┘
</pre>


### Option 4.2. peers ratings that are above Diana's global average

```sql
MATCH(diana:User{name:"Diana Robles"}) -[r:RATED] -()
WITH diana, AVG(r.rating) AS dianaAvgRating
CALL { WITH diana, dianaAvgRating
      MATCH (diana)-[:PEER] -(peer:User) - [rate:RATED] ->(m:Movie)
      WHERE rate.rating >  dianaAvgRating
      RETURN  m, rate, peer 
      ORDER BY  peer.score   DESC,  // peer similarity -- most similar peers first
                rate.rating  DESC   // peer rating     -- then their ratings
              }
WITH * 
WHERE NOT (diana)-[:RATED] -(m)
RETURN  m.title              AS title,  
   ROUND(AVG(rate.rating),2) AS peerRating, // average peer rating
   COUNT(DISTINCT peer) AS votes,           // votes
   m.imdbRating         AS imdbRating       // imdbRating as is
ORDER BY peerRating * votes DESC            // measure of film quality
LIMIT 10
```
The output is slightly different. "City of God (Cidade de Deus)" got moved to the bottom of the list

<pre>
╒════════════════════════════════════════════════╤══════════╤═════╤══════════╕
│title                                           │peerRating│votes│imdbRating│
╞════════════════════════════════════════════════╪══════════╪═════╪══════════╡
│"Shawshank Redemption, The"                     │4.6       │5    │9.3       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Bourne Identity, The"                          │4.1       │5    │7.9       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Silence of the Lambs, The"                     │4.5       │4    │8.6       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"There Will Be Blood"                           │4.5       │4    │8.1       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Star Wars: Episode V - The Empire Strikes Back"│4.38      │4    │8.8       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Toy Story"                                     │4.38      │4    │8.3       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Lord of the Rings: The Return of the King, The"│4.25      │4    │8.9       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"American Beauty"                               │4.25      │4    │8.4       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Terminator 2: Judgment Day"                    │4.13      │4    │8.5       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"City of God (Cidade de Deus)"                  │4.83      │3    │8.7       │
└────────────────────────────────────────────────┴──────────┴─────┴──────────┘

</pre>

### Option 4.3. peers ratings that are above Diana's genre-level average

This is a twist on Option 4.2. Only votes that are higher than Diana's genre level average ratings are counted in. To make it more restrictive, I added the threshold "at least 25% higher" in another constraint for peer's movie selection

```sql
MATCH(diana:User{name:"Diana Robles"}) -[r:RATED] -(m) -[:IN_GENRE] ->(genre:Genre)
WITH diana, genre, AVG(r.rating) AS dianaAvgRating 
CALL { WITH diana, dianaAvgRating,genre
      MATCH (diana)-[:PEER] - (peer:User) - [rate:RATED] ->(m:Movie) -[:IN_GENRE] ->(g:Genre)
      WHERE 1.0*rate.rating/dianaAvgRating > 1.25 
        AND g = genre
      RETURN  m, rate, peer 
      ORDER BY  peer.score   DESC,  // peer similarity -- most similar peers first
                rate.rating  DESC   // peer rating     -- then their ratings
              }
WITH * 
WHERE NOT (diana)-[:RATED] -(m)
RETURN  m.title              AS title,  
   ROUND(AVG(rate.rating),2) AS peerRating, // average peer rating
   COUNT(DISTINCT peer) AS votes,           // votes
   m.imdbRating         AS imdbRating       // imdbRating as is
ORDER BY peerRating * votes DESC            // measure of film quality
LIMIT 10
```

The output again is a bit different but count of votes is reduced.

<pre>
╒════════════════════════════════════════════════╤══════════╤═════╤══════════╕
│title                                           │peerRating│votes│imdbRating│
╞════════════════════════════════════════════════╪══════════╪═════╪══════════╡
│"Silence of the Lambs, The"                     │4.7       │4    │8.6       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"American Beauty"                               │4.4       │4    │8.4       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Toy Story"                                     │4.38      │4    │8.3       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Bourne Identity, The"                          │4.25      │4    │7.9       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Terminator 2: Judgment Day"                    │4.2       │4    │8.5       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Shawshank Redemption, The"                     │5.0       │3    │9.3       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"There Will Be Blood"                           │4.9       │3    │8.1       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"City of God (Cidade de Deus)"                  │4.83      │3    │8.7       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Collateral"                                    │4.83      │3    │7.6       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┤
│"Star Wars: Episode V - The Empire Strikes Back"│4.75      │3    │8.8       │
└────────────────────────────────────────────────┴──────────┴─────┴──────────┘
</pre>



### Option 4.4. Diana's preferred genres

Finally, restrict recommendations even more by only choosing movies from genres that with Diana's average rating higher than her global average rating. To make it more interesting, I added the list of genres that contributed to the selection of each movie for recommendations. This list is informative and also can be used for weighing the recommendations - the higher number of genres a movie has, the more likely Diana will watch it. 


```sql
MATCH (diana:User{name:"Diana Robles"})
CALL { WITH diana 
      MATCH (diana) -[a:RATED] -(gm)
      RETURN AVG(a.rating) AS dianaGlobalRating 
     }
MATCH(diana) -[r:RATED] -(m) -[:IN_GENRE] ->(genre:Genre)
WITH diana, genre, dianaGlobalRating, AVG(r.rating) AS dianaAvgRating 
WHERE dianaAvgRating > dianaGlobalRating
CALL { WITH diana, dianaAvgRating, genre
      MATCH (diana)-[:PEER] ->(peer:User) - [rate:RATED] ->(m:Movie) 
                   -[:IN_GENRE] ->(g:Genre)
      WHERE 1.0*rate.rating/dianaAvgRating > 1.25 
        AND g = genre
      RETURN  m, rate, peer, genre as peerGenre
      ORDER BY  peer.score   DESC,  // peer similarity -- most similar peers first
                rate.rating  DESC   // peer rating     -- then their ratings
     }
WITH * 
WHERE NOT (diana)-[:RATED] -(m)
RETURN  m.title              AS title,  
   ROUND(AVG(rate.rating),2) AS peerRating, // average peer rating
   COUNT(DISTINCT peer) AS votes,           // votes
   m.imdbRating         AS imdbRating,      // imdbRating as is
   collect(DISTINCT peerGenre.name) as genres // list of genres matching criteria
ORDER BY peerRating * votes DESC            // measure of film quality
LIMIT 10
```

The output below again is different. The last column with the list of genres may look confusing. However, "Toy Story" for example is listed under 
"Children", "Animation", "Comedy", "Adventure", and "Fantasy." It's because Diana's average rating for "Adventure" (_3.1857_) is higher than her global average rating (_3.1511_), Toy Story appears in this list. 

<pre>
╒════════════════════════════════════════════════╤══════════╤═════╤══════════╤═════════════════════════════════════════╕
│title                                           │peerRating│votes│imdbRating│genres                                   │
╞════════════════════════════════════════════════╪══════════╪═════╪══════════╪═════════════════════════════════════════╡
│"Toy Story"                                     │4.38      │4    │8.3       │["Adventure"]                            │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┼─────────────────────────────────────────┤
│"Bourne Identity, The"                          │4.25      │4    │7.9       │["Action", "Mystery"]                    │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┼─────────────────────────────────────────┤
│"Terminator 2: Judgment Day"                    │4.2       │4    │8.5       │["Action", "Sci-Fi"]                     │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┼─────────────────────────────────────────┤
│"Shawshank Redemption, The"                     │5.0       │3    │9.3       │["Crime", "Drama"]                       │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┼─────────────────────────────────────────┤
│"There Will Be Blood"                           │4.9       │3    │8.1       │["Drama", "Western"]                     │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┼─────────────────────────────────────────┤
│"City of God (Cidade de Deus)"                  │4.83      │3    │8.7       │["Crime", "Drama", "Adventure", "Action"]│
├────────────────────────────────────────────────┼──────────┼─────┼──────────┼─────────────────────────────────────────┤
│"Silence of the Lambs, The"                     │4.83      │3    │8.6       │["Crime"]                                │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┼─────────────────────────────────────────┤
│"Collateral"                                    │4.83      │3    │7.6       │["Crime", "Drama", "Action"]             │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┼─────────────────────────────────────────┤
│"Star Wars: Episode V - The Empire Strikes Back"│4.75      │3    │8.8       │["Adventure", "Action", "Sci-Fi"]        │
├────────────────────────────────────────────────┼──────────┼─────┼──────────┼─────────────────────────────────────────┤
│"Kung Fu Panda"                                 │4.67      │3    │7.6       │["Action", "IMAX"]                       │
└────────────────────────────────────────────────┴──────────┴─────┴──────────┴─────────────────────────────────────────┘

</pre>





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



<!-- 

```sql
match(u:User{name:"Diana Robles"}) -[r:RATED] -(m:Movie) <-[rp:RATED] - (peer:User) 
with u,peer,m,r,rp 
with  u, peer, round(1/(1+avg(abs(r.rating-rp.rating))),4) as manhattan, count(distinct m) as common
   , collect(r.rating) as r, collect(rp.rating) as rp
with u, peer, manhattan, common, 
  round(gds.similarity.cosine(r,rp),4) as cosine,
  round(gds.similarity.pearson(r,rp),4) as pearson,
  round(gds.similarity.euclidean(r,rp),4) as euclidean
  where 1.0*common/250 > 0.2
CALL{with peer match (peer) -[:RATED] -> (om:Movie) return count(distinct om) as peerRated }
return peer.name as Peer , peerRated, common as Common, 
round(1.0*common /(250 + peerRated - common),4) as Jaccard, manhattan, cosine,pearson,euclidean
order by euclidean desc 
 limit 10
```

-->


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



<!--

    match (diana:User{name:"Diana Robles"}) 
    match(peer:User) -[r:RATED] - (rec:Movie)
    where peer.name IN ["Kenneth Daniels"
,"Melissa Howard"
,"Kelsey White"
,"Elizabeth Powell"	
,"Amy Fischer"	
,"John Swanson"	
,"Michael Simmons"	
,"Gabriel Davila"	
,"Steven Rich"
,"Jose Miller"] 
    and not (diana) -[:RATED] -> (rec)
    and not rec.imdbRating is null
    return  rec.title as Recommendation, 
        rec.imdbRating as Score, count(peer) as Votes
    order by rec.imdbRating desc limit 10

--->


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


