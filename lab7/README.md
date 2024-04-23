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





