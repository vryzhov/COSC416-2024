# Lab 7: Dimensionality Reduction and data visualization

# Introduction

To start with, let's look at the [Visualizing high-dimensional space video](https://www.youtube.com/watch?v=wvsE8jm1GzE)

The goal of this class: 

1. Create Movie projection that contains Movie, User, Genre nodes with undirected relationships
2. Apply FastRP to embed Movies into a 1024-dimensional space
3. Write the embedding back to the original graph
4. Retrieve the Movie data in the Cypher query to export into a csv file
5. Use https://projector.tensorflow.org/ to see #D visualization of these data



## Movies 3D embedding

Like other labs, create projection, then compute similarity matrix for Movies. This lab focuses on Movies, not Users but the queries are essentially the same. 

```sql
CALL gds.graph.project("Movies", 
  ['Movie', 'User', 'Genre'], 
  { RATED:{orientation: "UNDIRECTED"}}
)
YIELD *
```

Check the projection

```sql
CALL gds.graph.list 
      yield degreeDistribution, graphName, memoryUsage,
      sizeInBytes, nodeCount, relationshipCount, 
      density, schemaWithOrientation   
```

Compute FastRP 

```sql

:param emeddingSpaceDim =>  1024;

CALL gds.fastRP.mutate (
     "Movies", 
    { embeddingDimension: $emeddingSpaceDim, 
      IterationWeights: [0.0,1.0,1.0,1.0,1.0], 
      randomSeed:7474, // for reproducibility 
      mutateProperty: "embedding" // property name
    }) YIELD *
```    

 I will write all these N-dimensional vectors back to the database's nodes
as their property called "embedding". The only nodes I care about are "Movie"


```sql
:param emeddingSpaceDim =>  1024;

match(m:Movie) set m.embedding = NULL;

CALL gds.fastRP.write (
     "Movies", 
    { embeddingDimension:$emeddingSpaceDim, 
      IterationWeights: [0.0,1.0,1.0,1.0,1.0], 
      randomSeed:7474, // for reproducibility 
      writeProperty: "embedding" // property name
    }) YIELD *
```    

Export query filters out movies projected to the null vector.

```sql
match(m:Movie) 
with m.title as title , m.embedding as embedding
WHERE reduce(total = 0, e IN embedding | total + abs(e) ) > 0
RETURN title, embedding
```    

After some offline manipulation, we have two files: one with data (embeddings), and another one with metadata (movie titles)



## Compute distance between movies

```sql
CALL gds.graph.project(
  "Movies", 
  {
      Movie: {
          properties:['embedding','imdbRating'] 
      }
  }, 
  '*'
)
YIELD *;  
```

## Closest movies 


```sql
CALL gds.knn.stream('Movies', {
    topK: 15,
    nodeProperties: ['embedding'],
   // randomSeed: 1337,
   // concurrency: 1,
    sampleRate: 1.0,
    deltaThreshold: 0.0
})
YIELD node1, node2, similarity
with gds.util.asNode(node1).title AS Title1, 
     substring(gds.util.asNode(node2).title,0, 40) AS Title2, 
     round(similarity,4) as similarity
where (    Title1 in [ 'Die Hard','Departed, The', 'Shrek'] 
        or Title1 starts with 'Man and a Woman' )
return Title1, Title2, similarity
ORDER BY Title1, similarity DESCENDING, Title2 
```

<pre>
Title1	Title2	similarity
"Departed, The"	"Casino Royale"	0.9975
"Departed, The"	"No Country for Old Men"	0.997
"Departed, The"	"V for Vendetta"	0.9968
"Departed, The"	"Batman Begins"	0.9964
"Departed, The"	"Dark Knight, The"	0.9963
"Departed, The"	"Prestige, The"	0.9961
"Departed, The"	"300"	0.9959
"Departed, The"	"Children of Men"	0.9958
"Departed, The"	"Bourne Ultimatum, The"	0.9957
"Departed, The"	"Little Miss Sunshine"	0.9957
"Departed, The"	"Pan's Labyrinth (Laberinto del fauno, El"	0.9957
"Departed, The"	"Juno"	0.9956
"Departed, The"	"Sin City"	0.9955
"Departed, The"	"Superbad"	0.9955
"Departed, The"	"Shaun of the Dead"	0.9954
"Die Hard"	"Terminator, The"	0.9984
"Die Hard"	"Indiana Jones and the Last Crusade"	0.9983
"Die Hard"	"Raiders of the Lost Ark (Indiana Jones a"	0.998
"Die Hard"	"Back to the Future"	0.9979
"Die Hard"	"Star Wars: Episode V - The Empire Strike"	0.9978
"Die Hard"	"Aliens"	0.9977
"Die Hard"	"Star Wars: Episode VI - Return of the Je"	0.9977
"Die Hard"	"Star Wars: Episode IV - A New Hope"	0.9975
"Die Hard"	"Men in Black (a.k.a. MIB)"	0.9973
"Die Hard"	"Blade Runner"	0.9972
"Die Hard"	"Face/Off"	0.9972
"Die Hard"	"E.T. the Extra-Terrestrial"	0.9971
"Die Hard"	"Groundhog Day"	0.9971
"Die Hard"	"Saving Private Ryan"	0.9971
"Die Hard"	"Total Recall"	0.9971
"Man and a Woman, A (Un homme et une femme)"	"Red Sorghum (Hong gao liang)"	0.968
"Man and a Woman, A (Un homme et une femme)"	"Only Angels Have Wings"	0.9659
"Man and a Woman, A (Un homme et une femme)"	"Grapes of Wrath, The"	0.9646
"Man and a Woman, A (Un homme et une femme)"	"On the Waterfront"	0.9645
"Man and a Woman, A (Un homme et une femme)"	"Five Easy Pieces"	0.964
"Man and a Woman, A (Un homme et une femme)"	"Who's Afraid of Virginia Woolf?"	0.9639
"Man and a Woman, A (Un homme et une femme)"	"Laura"	0.9637
"Man and a Woman, A (Un homme et une femme)"	"From Here to Eternity"	0.963
"Man and a Woman, A (Un homme et une femme)"	"Treasure of the Sierra Madre, The"	0.9628
"Man and a Woman, A (Un homme et une femme)"	"Hud"	0.9625
"Man and a Woman, A (Un homme et une femme)"	"Splendor in the Grass"	0.9619
"Man and a Woman, A (Un homme et une femme)"	"Ordinary People"	0.9616
"Man and a Woman, A (Un homme et une femme)"	"Third Man, The"	0.9614
"Man and a Woman, A (Un homme et une femme)"	"Hustler, The"	0.9612
"Man and a Woman, A (Un homme et une femme)"	"Prizzi's Honor"	0.9612
"Shrek"	"Monsters, Inc."	0.9988
"Shrek"	"Lord of the Rings: The Two Towers, The"	0.9987
"Shrek"	"Pirates of the Caribbean: The Curse of t"	0.9987
"Shrek"	"Lord of the Rings: The Fellowship of the"	0.9986
"Shrek"	"Spider-Man"	0.9986
"Shrek"	"Finding Nemo"	0.9985
"Shrek"	"Ocean's Eleven"	0.9984
"Shrek"	"Catch Me If You Can"	0.9981
"Shrek"	"Harry Potter and the Sorcerer's Stone (a"	0.9981
"Shrek"	"Incredibles, The"	0.9981
"Shrek"	"Beautiful Mind, A"	0.9978
"Shrek"	"Lord of the Rings: The Return of the Kin"	0.9978
"Shrek"	"Minority Report"	0.9978
"Shrek"	"Bourne Identity, The"	0.9977
"Shrek"	"Shrek 2"	0.9977
</pre>