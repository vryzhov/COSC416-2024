# Lab 6: Recommendation Engines III. Recommendations quality

# Introduction

Your goal of this Lab is tgh use of GDS algorithms for recommendations and subsequent 
estimation of their relevance to the user of interest. 

This lab assumes your familiarity with the class material. 

# Setup


This lab is based on the Movies database created for Labs 4 and 5


# Part 1. Peer similarity 


The first part of the lab is concerned with the use of GDS algorithms `FastRP` and `kNN`.  Execute the queries below in sequence. Feel free to use _.estimate_   if there are concerns related to the CPU/Memory resources available

## Step 1.1 Create GDS Projection

Create native GDS projection "Peers" for nodes *Movie*, *User* and relationships *RATED*. Make relationships undirected and 

```sql
CALL gds.graph.project("Peers", 
  ['Movie', 'User'], 
  { RATED:{orientation: "UNDIRECTED"}}
)
YIELD *
```

## Step 1.2. Create embedding with FastRP 

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

## Step 1.3. Identify top 5 peers using kNN node similarity algorithm

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

## Step 1.4. Recommendations

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



### Option 1.4.1. average peer ratings only

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


### Option 1.4.2. peers ratings that are above Diana's global average

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

### Option 1.4.3. peers ratings that are above Diana's genre-level average

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



### Option 1.4.4. Diana's preferred genres

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


# Part 2. Validation

Validation of recommendations relevance will use the random split or Diana's movies and create the "Validation" set. The terms "training" and "validation" sets are commonly used in predictive analytics and machine learning. Our situation a bit different but the same terminology will be used.  

We can think of Validation set as a movies that "Diana has not watched yet."
These movies cannot be used to identify her peers, but they will be included in the  recommendations. Then the recommendation quality be measured by Jaccard similarity between the set of recommended movies and movies from the Validation set. 

## Step 2.1. Validation set

We will allocate 20% of Diana's movies for Validation. 

It is possible to carve a Cypher query and use Cypher projection to build a GDS graph but it appears easier to just add labels to Movie nodes and create a Native projection instead.



```sql
// Step 1: Split Diana’s movies into two sets. 
//     Add an attribute "dataset" first that will be 
//     used to add labels to Movie nodes
MATCH(u:User) -[r:RATED] -> (m:Movie)
WHERE u.name = "Diana Robles"
SET m.dataset =  CASE WHEN rand() < 0.8 THEN "Train"
                      ELSE "Validation" END
RETURN m.title, m.dataset ;

// Step 2: Add Validation label (to use by Native GDS projection)
MATCH(u:User) -[r:RATED] -(m:Movie)
WHERE u.name = "Diana Robles" AND m.dataset = "Validation" 
SET m:Validation;   

// Step 3: All other movies go into Train set (to use by GDS projection)
MATCH(u:User) -[r:RATED] -(m:Movie)
WHERE  m.dataset is NULL OR m.dataset <> "Validation"
SET m:Train;   
    

```
## Step 2.2. Identify peers ignoring Diana's Validation set 


First, create GDS projection that does not included Validation movies

```sql
// Step 1: Create Projection for Peers identification
CALL gds.graph.project("PeersTrain", 
  ["Train", 'User'], 
  {RATED:{orientation: "UNDIRECTED"}}
) YIELD *;
```

Apply _fastRP_ and save the results in the PeersTrain projection

```sql
CALL gds.fastRP.mutate (
     'PeersTrain', 
    { embeddingDimension:64, 
      IterationWeights: [0.0,1.0,1.0,1.0], 
      randomSeed:7474,     
      mutateProperty: 'embedding'
    }) YIELD *
```
Identify top 5 peers by kNN algorithm and write the *PEER_TRAIN* relationship with the _score_ attribute  back to the graph.

```sql
CALL gds.knn.write('PeersTrain', 
 {nodeLabels:["User"],  
 nodeProperties:'embedding', topK:5,
 writeRelationshipType: "PEER_TRAIN",
 writeProperty: "score"})
YIELD *
```

## Step 2.3. Recommendations and Quality 

The recommendations quality will be measured by Jaccard index between the Validation set and the Top 10, 20, 30, and 50 recommendations ordered by recommendation "score." 


### Option 1. average peer ratings only

```sql
MATCH(diana:User{name:"Diana Robles"})
CALL { WITH diana 
      MATCH (diana)-[:PEER_TRAIN] // Peers defined by the TRAIN set only
          - (peer:User) - [rate:RATED] ->(m:Movie)
      RETURN  m, rate, peer 
      ORDER BY  peer.score   DESC,  // peer similarity -- most similar peers first
                rate.rating  DESC   // peer rating     -- then their ratings
              }
WITH m, // movies recommended by peers
   ROUND(AVG(rate.rating),2) AS peerRating, // average peer rating
   COUNT(DISTINCT peer) AS votes,           // votes
   m.imdbRating         AS imdbRating       // imdbRating as is
ORDER BY peerRating * votes DESC            // measure of film quality (score)
WITH COLLECT(ID(m)) as recommendation       // collect all recommendations ordered by score
CALL {match(mt:Validation) return collect(ID(mt)) as validation } // validation set
RETURN size(recommendation) AS sizeof_rec ,
       size(validation)     AS sizeof_val, 
    ROUND(gds.similarity.jaccard(recommendation[0..9], validation),4) 
      AS quality_10,
    ROUND(gds.similarity.jaccard(recommendation[0..19], validation),4) 
      AS quality_20, 
    ROUND(gds.similarity.jaccard(recommendation[0..29], validation),4) 
      AS quality_30,
    ROUND(gds.similarity.jaccard(recommendation[0..39], validation),4) 
      AS quality_40,
    ROUND(gds.similarity.jaccard(recommendation[0..49], validation),4) 
      AS quality_50
```
<pre>
╒══════════╤══════════╤══════════╤══════════╤══════════╤══════════╤══════════╕
│sizeof_rec│sizeof_val│quality_10│quality_20│quality_30│quality_40│quality_50│
╞══════════╪══════════╪══════════╪══════════╪══════════╪══════════╪══════════╡
│668       │54        │0.0161    │0.0139    │0.0247    │0.0333    │0.051     │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
</pre>



### Option 2. peers ratings that are above Diana's global average

```sql
MATCH(diana:User{name:"Diana Robles"}) -[r:RATED] -()
WITH diana, AVG(r.rating) AS dianaAvgRating
CALL { WITH diana, dianaAvgRating
      MATCH (diana)-[:PEER_TRAIN]  // Peers defined by the TRAIN set only
        -(peer:User) - [rate:RATED] ->(m:Movie)
      WHERE rate.rating >  dianaAvgRating
      RETURN  m, rate, peer 
      ORDER BY  peer.score   DESC,  // peer similarity -- most similar peers first
                rate.rating  DESC   // peer rating     -- then their ratings
              }
WITH m,                                     // movies recommended by peers 
   ROUND(AVG(rate.rating),2) AS peerRating, // average peer rating
   COUNT(DISTINCT peer) AS votes,           // votes
   m.imdbRating         AS imdbRating       // imdbRating as is
ORDER BY peerRating * votes DESC            // measure of film quality
WITH COLLECT(ID(m)) as recommendation       // collect all recommendations ordered by score
CALL {match(mt:Validation) return collect(ID(mt)) as validation } // validation set
RETURN size(recommendation) AS sizeof_rec ,
       size(validation)     AS sizeof_val, 
    ROUND(gds.similarity.jaccard(recommendation[0..9], validation),4) 
      AS quality_10,
    ROUND(gds.similarity.jaccard(recommendation[0..19], validation),4) 
      AS quality_20, 
    ROUND(gds.similarity.jaccard(recommendation[0..29], validation),4) 
      AS quality_30,
    ROUND(gds.similarity.jaccard(recommendation[0..39], validation),4) 
      AS quality_40,
    ROUND(gds.similarity.jaccard(recommendation[0..49], validation),4) 
      AS quality_50
```

<pre>
╒══════════╤══════════╤══════════╤══════════╤══════════╤══════════╤══════════╕
│sizeof_rec│sizeof_val│quality_10│quality_20│quality_30│quality_40│quality_50│
╞══════════╪══════════╪══════════╪══════════╪══════════╪══════════╪══════════╡
│484       │54        │0.0161    │0.0139    │0.0375    │0.0568    │0.051     │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
</pre>

### Option 3. peers ratings that are above Diana's genre-level average

```sql
MATCH(diana:User{name:"Diana Robles"}) -[r:RATED] -(m) -[:IN_GENRE] ->(genre:Genre)
WITH diana, genre, AVG(r.rating) AS dianaAvgRating 
CALL { WITH diana, dianaAvgRating,genre
      MATCH (diana)-[:PEER_TRAIN]  // Peers defined by the TRAIN set only
        - (peer:User) - [rate:RATED] ->(m:Movie) -[:IN_GENRE] ->(g:Genre)
      WHERE 1.0*rate.rating/dianaAvgRating > 1.25 
        AND g = genre
      RETURN  m, rate, peer 
      ORDER BY  peer.score   DESC,  // peer similarity -- most similar peers first
                rate.rating  DESC   // peer rating     -- then their ratings
              }
WITH m,                                     // movies recommended by peers 
   ROUND(AVG(rate.rating),2) AS peerRating, // average peer rating
   COUNT(DISTINCT peer) AS votes,           // votes
   m.imdbRating         AS imdbRating       // imdbRating as is
ORDER BY peerRating * votes DESC            // measure of film quality
WITH COLLECT(ID(m)) as recommendation       // collect all recommendations ordered by score
CALL {match(mt:Validation) return collect(ID(mt)) as validation } // validation set
RETURN size(recommendation) AS sizeof_rec ,
       size(validation)     AS sizeof_val, 
    ROUND(gds.similarity.jaccard(recommendation[0..9], validation),4) 
      AS quality_10,
    ROUND(gds.similarity.jaccard(recommendation[0..19], validation),4) 
      AS quality_20, 
    ROUND(gds.similarity.jaccard(recommendation[0..29], validation),4) 
      AS quality_30,
    ROUND(gds.similarity.jaccard(recommendation[0..39], validation),4) 
      AS quality_40,
    ROUND(gds.similarity.jaccard(recommendation[0..49], validation),4) 
      AS quality_50
```
<pre>
╒══════════╤══════════╤══════════╤══════════╤══════════╤══════════╤══════════╕
│sizeof_rec│sizeof_val│quality_10│quality_20│quality_30│quality_40│quality_50│
╞══════════╪══════════╪══════════╪══════════╪══════════╪══════════╪══════════╡
│350       │54        │0.0       │0.0139    │0.0375    │0.0449    │0.0404    │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
</pre>


### Option 4. Diana's preferred genres

```sql
MATCH (diana:User{name:"Diana Robles"})
CALL { WITH diana 
      MATCH (diana) -[a:RATED] -(gm)
      RETURN AVG(a.rating) AS dianaGlobalRating 
     }
MATCH(diana) -[r:RATED] -(m) -[:IN_GENRE] ->(genre:Genre)
WITH diana, genre, dianaGlobalRating, AVG(r.rating) AS dianaAvgRating 
WHERE dianaAvgRating > dianaGlobalRating
CALL { WITH diana, dianaAvgRating, genre
      MATCH (diana)-[:PEER_TRAIN]  // Peers defined by the TRAIN set only
            -(peer:User) - [rate:RATED] ->(m:Movie) 
                   -[:IN_GENRE] ->(g:Genre)
      WHERE 1.0*rate.rating/dianaAvgRating > 1.25 
        AND g = genre
      RETURN  m, rate, peer, genre as peerGenre
      ORDER BY  peer.score   DESC,  // peer similarity -- most similar peers first
                rate.rating  DESC   // peer rating     -- then their ratings
     }
WITH m,                                     // movies recommended by peers 
   ROUND(AVG(rate.rating),2) AS peerRating, // average peer rating
   COUNT(DISTINCT peer) AS votes,           // votes
   m.imdbRating         AS imdbRating,      // imdbRating as is
   collect(DISTINCT peerGenre.name) as genres // list of genres matching criteria
ORDER BY peerRating * votes DESC            // measure of film quality
WITH COLLECT(ID(m)) as recommendation       // collect all recommendations ordered by score
CALL {match(mt:Validation) return collect(ID(mt)) as validation } // validation set
RETURN size(recommendation) AS sizeof_rec ,
       size(validation)     AS sizeof_val, 
    ROUND(gds.similarity.jaccard(recommendation[0..9], validation),4) 
      AS quality_10,
    ROUND(gds.similarity.jaccard(recommendation[0..19], validation),4) 
      AS quality_20, 
    ROUND(gds.similarity.jaccard(recommendation[0..29], validation),4) 
      AS quality_30,
    ROUND(gds.similarity.jaccard(recommendation[0..39], validation),4) 
      AS quality_40,
    ROUND(gds.similarity.jaccard(recommendation[0..49], validation),4) 
      AS quality_50
```

<pre>
╒══════════╤══════════╤══════════╤══════════╤══════════╤══════════╤══════════╕
│sizeof_rec│sizeof_val│quality_10│quality_20│quality_30│quality_40│quality_50│
╞══════════╪══════════╪══════════╪══════════╪══════════╪══════════╪══════════╡
│275       │54        │0.0       │0.0139    │0.0375    │0.0449    │0.0404    │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
</pre>



### All results together: 


<pre>
Option 1. average peer ratings only
╒══════════╤══════════╤══════════╤══════════╤══════════╤══════════╤══════════╕
│sizeof_rec│sizeof_val│quality_10│quality_20│quality_30│quality_40│quality_50│
╞══════════╪══════════╪══════════╪══════════╪══════════╪══════════╪══════════╡
│668       │54        │0.0161    │0.0139    │0.0247    │0.0333    │0.051     │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘

Option 2. peers ratings that are above Diana's global average
╒══════════╤══════════╤══════════╤══════════╤══════════╤══════════╤══════════╕
│sizeof_rec│sizeof_val│quality_10│quality_20│quality_30│quality_40│quality_50│
╞══════════╪══════════╪══════════╪══════════╪══════════╪══════════╪══════════╡
│484       │54        │0.0161    │0.0139    │0.0375    │0.0568    │0.051     │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘

Option 3. peers ratings that are above Diana's genre-level average
╒══════════╤══════════╤══════════╤══════════╤══════════╤══════════╤══════════╕
│sizeof_rec│sizeof_val│quality_10│quality_20│quality_30│quality_40│quality_50│
╞══════════╪══════════╪══════════╪══════════╪══════════╪══════════╪══════════╡
│350       │54        │0.0       │0.0139    │0.0375    │0.0449    │0.0404    │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘

Option 4. Diana's preferred genres
╒══════════╤══════════╤══════════╤══════════╤══════════╤══════════╤══════════╕
│sizeof_rec│sizeof_val│quality_10│quality_20│quality_30│quality_40│quality_50│
╞══════════╪══════════╪══════════╪══════════╪══════════╪══════════╪══════════╡
│275       │54        │0.0       │0.0139    │0.0375    │0.0449    │0.0404    │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
</pre>


The quality is measured by the highest Jaccard index reached by the lowest count of Top recommendations. Based on this definition, Option 2 is a winner reaching 0.0568 for Top 40 recommended movies. This result can be improved by making selection of recommended movies more conservative. Below is the table for the same query with `WHERE rate.rating >  dianaAvgRating` replaced by `WHERE rate.rating >  1.25*dianaAvgRating` (the average ragin of recommended movie must be at least 25% higher than Diana's overall raging average)
<pre>
╒══════════╤══════════╤══════════╤══════════╤══════════╤══════════╤══════════╕
│sizeof_rec│sizeof_val│quality_10│quality_20│quality_30│quality_40│quality_50│
╞══════════╪══════════╪══════════╪══════════╪══════════╪══════════╪══════════╡
│356       │54        │0.0       │0.0139    │0.0506    │0.0568    │0.051     │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
</pre>

The top 30 movies reach the Jaccard index of _0.0506_ for this setup.

It appears that inclusion of genres into recommendation decisions has a negative effect on the quality. This could be attributed to a rather vague classification of movies by genre. 








## Submission

Collect all your results - Cypher queries, solutions, thoughts, conjectures, etc. - into a document, <u>**convert it to a PDF file**</u> and submit before the deadline. 


### Content based and collaborative filtering recommendations

See [Lab 4](https://github.com/vryzhov/COSC416-2024/tree/main/lab4)    

See [Lab 5](https://github.com/vryzhov/COSC416-2024/tree/main/lab5)   


